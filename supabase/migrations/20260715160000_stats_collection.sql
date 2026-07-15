-- Stats collection: time-to-first-touch, escalation latency, reopen rate, and a
-- nightly daily_stats rollup so reporting stays fast as data grows.

-- ============================================================
-- New columns.
--   cases.first_touch_at      — first agent action (note or status change).
--   cases.reopen_count        — times a closed/resolved case was reopened.
--   escalation_audit.escalation_latency_hours — creation → escalation, in hours.
-- ("Assignment → escalation" uses created_at as the baseline: there is no
--  assigned_at column, and most cases are assigned at creation.)
-- ============================================================
alter table cases add column if not exists first_touch_at timestamptz;
alter table cases add column if not exists reopen_count int not null default 0;
alter table escalation_audit add column if not exists escalation_latency_hours numeric;

-- ============================================================
-- Fold the new metrics into the existing status-change trigger:
--   * first_touch_at stamped on the first status change (an agent action),
--   * escalation_latency_hours captured when the audit row is written,
--   * reopen_count incremented when a closed/resolved case goes back to open.
-- Everything else is preserved verbatim.
-- ============================================================
create or replace function public.handle_case_status_change()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if new.status is distinct from old.status then
    insert into case_status_history (case_id, old_status, new_status, changed_by)
    values (new.id, old.status, new.status, auth.uid());
    -- A status change is an agent working the case: record first touch.
    new.first_touch_at := coalesce(new.first_touch_at, now());
  end if;

  if new.status = 'escalated' and old.status is distinct from 'escalated' then
    new.escalated_at := coalesce(new.escalated_at, now());
    new.escalated_by := coalesce(new.escalated_by, auth.uid());
    new.times_escalated := coalesce(old.times_escalated, 0) + 1;
    new.escalation_overdue_notified := false;
    new.escalation_prebreach_notified := false;
    if new.escalation_timer_hours is not null then
      new.escalation_expires_at := new.escalated_at + (new.escalation_timer_hours * interval '1 hour');
    end if;

    insert into escalation_audit (case_id, escalated_by, escalated_at, escalation_reason_id, service_centre_id, timer_hours, escalation_latency_hours)
    values (new.id, new.escalated_by, new.escalated_at, new.escalation_reason_id, new.service_centre_id, new.escalation_timer_hours,
            round((extract(epoch from (new.escalated_at - new.created_at)) / 3600)::numeric, 2));
  end if;

  if new.status = 'escalated' and old.status = 'escalated'
     and (new.escalation_timer_hours is distinct from old.escalation_timer_hours) then
    if new.escalation_timer_hours is not null then
      new.escalation_expires_at := coalesce(new.escalated_at, old.escalated_at) + (new.escalation_timer_hours * interval '1 hour');
    else
      new.escalation_expires_at := null;
    end if;
    new.escalation_overdue_notified := false;
    new.escalation_prebreach_notified := false;
  end if;

  if old.status = 'escalated' and new.status is distinct from 'escalated' then
    update escalation_audit
      set closed_at = now(),
          closed_by = auth.uid(),
          was_overdue = (old.escalation_expires_at is not null and now() > old.escalation_expires_at)
      where case_id = new.id and closed_at is null;
  end if;

  if new.status in ('closed', 'resolved') and old.status not in ('closed', 'resolved') then
    new.closed_at := coalesce(new.closed_at, now());
    new.closed_by := coalesce(auth.uid(), new.closed_by, new.assigned_to);

    insert into activity_feed (actor_id, type, case_number)
    values (new.closed_by, 'case_closed', new.case_number);
  elsif new.status not in ('closed', 'resolved') and old.status in ('closed', 'resolved') then
    new.closed_at := null;
    new.closed_by := null;
    -- Reopened: a closed/resolved case moved back to an open status.
    new.reopen_count := coalesce(old.reopen_count, 0) + 1;
  end if;

  return new;
end;
$function$;

-- Notes also count as a first touch. AFTER INSERT so the note is committed;
-- the WHERE ... is null clause makes this a no-op after the first note.
create or replace function public.set_case_first_touch_from_note()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  update cases set first_touch_at = now()
    where id = new.case_id and first_touch_at is null;
  return new;
end;
$function$;

drop trigger if exists trg_50_case_first_touch_from_note on case_notes;
create trigger trg_50_case_first_touch_from_note
  after insert on case_notes
  for each row execute function public.set_case_first_touch_from_note();

-- ============================================================
-- Backfill historical rows so the new metrics aren't blank for old data.
-- ============================================================
update escalation_audit ea
  set escalation_latency_hours = round((extract(epoch from (ea.escalated_at - c.created_at)) / 3600)::numeric, 2)
  from cases c
  where ea.case_id = c.id and ea.escalation_latency_hours is null and ea.escalated_at is not null;

update cases c
  set first_touch_at = t.first_action
  from (
    select case_id, min(ts) as first_action from (
      select case_id, created_at as ts from case_notes
      union all
      select case_id, changed_at as ts from case_status_history
    ) actions group by case_id
  ) t
  where c.id = t.case_id and c.first_touch_at is null;

update cases c
  set reopen_count = r.cnt
  from (
    select case_id, count(*) as cnt from case_status_history
    where old_status in ('closed', 'resolved') and new_status not in ('closed', 'resolved')
    group by case_id
  ) r
  where c.id = r.case_id and c.reopen_count = 0;

-- ============================================================
-- Nightly rollup: one daily_stats row per active agent, upserted so a re-run
-- for the same date is idempotent (unique(agent_id, date) already exists).
-- ============================================================
create or replace function public.compute_daily_stats(target_date date)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  insert into daily_stats (
    agent_id, date, cases_created, cases_closed, cases_interacted,
    escalated_count, awaiting_response, avg_response_time_hours,
    avg_resolution_time_hours, sla_breach_count
  )
  select p.id, target_date,
    (select count(*) from cases c where c.assigned_to = p.id and c.created_at::date = target_date),
    (select count(*) from cases c where c.closed_by = p.id and c.closed_at::date = target_date),
    (select count(distinct cn.case_id) from case_notes cn where cn.user_id = p.id and cn.created_at::date = target_date),
    (select count(*) from escalation_audit ea where ea.escalated_by = p.id and ea.escalated_at::date = target_date),
    (select count(distinct csh.case_id) from case_status_history csh where csh.changed_by = p.id and csh.changed_at::date = target_date and csh.new_status in ('awaiting_internal', 'awaiting_customer')),
    (select round(avg(extract(epoch from (c.first_touch_at - c.created_at)) / 3600)::numeric, 2) from cases c where c.assigned_to = p.id and c.first_touch_at is not null and c.first_touch_at::date = target_date),
    (select round(avg(extract(epoch from (c.closed_at - c.created_at)) / 3600)::numeric, 2) from cases c where c.closed_by = p.id and c.closed_at::date = target_date),
    (select count(*) from escalation_audit ea where ea.closed_by = p.id and ea.was_overdue and ea.closed_at::date = target_date)
  from profiles p
  where p.role = 'agent' and p.is_active
  on conflict (agent_id, date) do update set
    cases_created = excluded.cases_created,
    cases_closed = excluded.cases_closed,
    cases_interacted = excluded.cases_interacted,
    escalated_count = excluded.escalated_count,
    awaiting_response = excluded.awaiting_response,
    avg_response_time_hours = excluded.avg_response_time_hours,
    avg_resolution_time_hours = excluded.avg_resolution_time_hours,
    sla_breach_count = excluded.sla_breach_count;
end;
$function$;

revoke execute on function public.compute_daily_stats(date) from public;

-- Schedule it nightly at 00:30 UTC for the day that just ended. cron.schedule
-- upserts by job name, so re-applying this migration is safe.
select cron.schedule('nightly-daily-stats', '30 0 * * *', $$select public.compute_daily_stats((current_date - 1));$$);
