-- Culligan Case Tracker: backend automation
-- 1) updated_at auto-maintenance
-- 2) case number generation
-- 3) status-change history / escalation bookkeeping
-- 4) denormalised field sync (department, last-note summary)
-- 5) notifications table + admin-configurable end-of-day team stats (pg_cron)

-- ============================================================
-- 1) updated_at auto-maintenance
-- ============================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_90_profiles_updated_at
  before update on profiles
  for each row execute function public.set_updated_at();

create trigger trg_90_cases_updated_at
  before update on cases
  for each row execute function public.set_updated_at();

create trigger trg_90_email_templates_updated_at
  before update on email_templates
  for each row execute function public.set_updated_at();

create trigger trg_90_escalation_templates_updated_at
  before update on escalation_templates
  for each row execute function public.set_updated_at();

-- ============================================================
-- 2) Case number generation (e.g. 00248485)
-- ============================================================
create sequence if not exists public.case_number_seq start 248485;

create or replace function public.generate_case_number()
returns trigger
language plpgsql
as $$
begin
  if new.case_number is null then
    new.case_number := lpad(nextval('public.case_number_seq')::text, 8, '0');
  end if;
  return new;
end;
$$;

create trigger trg_10_cases_generate_number
  before insert on cases
  for each row execute function public.generate_case_number();

-- ============================================================
-- 4) Denormalised field sync
-- ============================================================
create or replace function public.sync_case_department()
returns trigger
security definer
set search_path = public
language plpgsql
as $$
begin
  if new.assigned_to is not null and (tg_op = 'INSERT' or new.assigned_to is distinct from old.assigned_to) then
    select department_id into new.department_id from profiles where id = new.assigned_to;
  end if;
  return new;
end;
$$;

create trigger trg_20_cases_sync_department
  before insert or update of assigned_to on cases
  for each row execute function public.sync_case_department();

create or replace function public.sync_case_last_note()
returns trigger
security definer
set search_path = public
language plpgsql
as $$
begin
  update cases set notes = left(new.note, 280) where id = new.case_id;
  return new;
end;
$$;

create trigger trg_case_notes_sync_summary
  after insert on case_notes
  for each row execute function public.sync_case_last_note();

-- ============================================================
-- 3) Status-change history / escalation bookkeeping
-- ============================================================
create or replace function public.handle_case_status_change()
returns trigger
security definer
set search_path = public
language plpgsql
as $$
begin
  if new.status is distinct from old.status then
    insert into case_status_history (case_id, old_status, new_status, changed_by)
    values (new.id, old.status, new.status, auth.uid());
  end if;

  -- newly escalated
  if new.status = 'escalated' and old.status is distinct from 'escalated' then
    new.escalated_at := coalesce(new.escalated_at, now());
    new.escalated_by := coalesce(new.escalated_by, auth.uid());
    new.times_escalated := coalesce(old.times_escalated, 0) + 1;
    if new.escalation_timer_hours is not null then
      new.escalation_expires_at := new.escalated_at + (new.escalation_timer_hours * interval '1 hour');
    end if;

    insert into escalation_audit (case_id, escalated_by, escalated_at, escalation_reason_id, service_centre_id, timer_hours)
    values (new.id, new.escalated_by, new.escalated_at, new.escalation_reason_id, new.service_centre_id, new.escalation_timer_hours);
  end if;

  -- timer changed while still escalated: recompute expiry
  if new.status = 'escalated' and old.status = 'escalated'
     and (new.escalation_timer_hours is distinct from old.escalation_timer_hours) then
    if new.escalation_timer_hours is not null then
      new.escalation_expires_at := coalesce(new.escalated_at, old.escalated_at) + (new.escalation_timer_hours * interval '1 hour');
    else
      new.escalation_expires_at := null;
    end if;
  end if;

  -- escalation resolved (left the escalated state)
  if old.status = 'escalated' and new.status is distinct from 'escalated' then
    update escalation_audit
      set closed_at = now(),
          was_overdue = (old.escalation_expires_at is not null and now() > old.escalation_expires_at)
      where case_id = new.id and closed_at is null;
  end if;

  -- closing a case
  if new.status in ('closed', 'resolved') and old.status not in ('closed', 'resolved') then
    new.closed_at := coalesce(new.closed_at, now());
  elsif new.status not in ('closed', 'resolved') and old.status in ('closed', 'resolved') then
    new.closed_at := null;
  end if;

  return new;
end;
$$;

create trigger trg_30_cases_status_change
  before update on cases
  for each row execute function public.handle_case_status_change();

-- ============================================================
-- 5) Notifications + admin-configurable end-of-day team stats
-- ============================================================
create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  data jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_notifications_user on notifications(user_id, is_read);

alter table notifications enable row level security;

create policy "users_read_own_notifications" on notifications for select
  using (user_id = auth.uid());
create policy "users_update_own_notifications" on notifications for update
  using (user_id = auth.uid());
create policy "admins_all_notifications" on notifications for all
  using (public.is_admin()) with check (public.is_admin());

-- Singleton settings row admins can update from the admin panel.
create table org_settings (
  id boolean primary key default true,
  eod_stats_enabled boolean not null default true,
  eod_stats_time time not null default '18:00',
  eod_stats_timezone text not null default 'Europe/London',
  eod_stats_last_run_date date,
  updated_at timestamptz not null default now(),
  constraint org_settings_singleton check (id)
);

insert into org_settings (id) values (true);

alter table org_settings enable row level security;

create policy "authenticated_read_org_settings" on org_settings for select
  using (auth.role() = 'authenticated');
create policy "admins_write_org_settings" on org_settings for update
  using (public.is_admin()) with check (public.is_admin());

create trigger trg_90_org_settings_updated_at
  before update on org_settings
  for each row execute function public.set_updated_at();

-- Computes and fans out today's collective team stats to every active agent/admin.
create or replace function public.send_eod_stats(for_date date)
returns void
security definer
set search_path = public
language plpgsql
as $$
declare
  v_cases_closed int;
  v_cases_created int;
  v_cases_interacted int;
  v_escalated_count int;
  v_sla_breach_count int;
  v_top_performer text;
  v_top_closed int;
  v_title text;
  v_body text;
begin
  select count(*) into v_cases_closed from cases where closed_at::date = for_date;
  select count(*) into v_cases_created from cases where created_at::date = for_date;
  select count(distinct case_id) into v_cases_interacted from case_notes where created_at::date = for_date;
  select count(*) into v_escalated_count from cases where escalated_at::date = for_date;
  select count(*) into v_sla_breach_count from cases where sla_date < for_date and closed_at is null;

  select p.full_name, cnt into v_top_performer, v_top_closed
  from (
    select assigned_to, count(*) as cnt
    from cases
    where closed_at::date = for_date and assigned_to is not null
    group by assigned_to
    order by count(*) desc
    limit 1
  ) t
  join profiles p on p.id = t.assigned_to;

  v_title := 'End of day stats – ' || to_char(for_date, 'DD Mon YYYY');
  v_body := format(
    'Team results for today: %s cases closed, %s new cases, %s cases interacted with, %s escalations, %s SLA breaches.%s',
    v_cases_closed, v_cases_created, v_cases_interacted, v_escalated_count, v_sla_breach_count,
    case when v_top_performer is not null
      then format(' Top performer: %s (%s closed).', v_top_performer, v_top_closed)
      else ''
    end
  );

  insert into notifications (user_id, type, title, body, data)
  select
    p.id,
    'eod_stats',
    v_title,
    v_body,
    jsonb_build_object(
      'date', for_date,
      'cases_closed', v_cases_closed,
      'cases_created', v_cases_created,
      'cases_interacted', v_cases_interacted,
      'escalated_count', v_escalated_count,
      'sla_breach_count', v_sla_breach_count,
      'top_performer', v_top_performer,
      'top_performer_closed', v_top_closed
    )
  from profiles p
  where p.is_active = true;
end;
$$;

-- Runs every minute; fires send_eod_stats once per day at the admin-configured local time.
create or replace function public.maybe_send_eod_stats()
returns void
security definer
set search_path = public
language plpgsql
as $$
declare
  settings record;
  local_now timestamp;
  today date;
begin
  select * into settings from org_settings where id = true;
  if not found or not settings.eod_stats_enabled then
    return;
  end if;

  local_now := now() at time zone settings.eod_stats_timezone;
  today := local_now::date;

  if settings.eod_stats_last_run_date is not distinct from today then
    return;
  end if;

  if local_now::time < settings.eod_stats_time then
    return;
  end if;

  perform public.send_eod_stats(today);

  update org_settings set eod_stats_last_run_date = today where id = true;
end;
$$;

create extension if not exists pg_cron with schema extensions;

select cron.unschedule(jobid) from cron.job where jobname = 'eod-stats-check';

select cron.schedule('eod-stats-check', '* * * * *', $$select public.maybe_send_eod_stats();$$);
