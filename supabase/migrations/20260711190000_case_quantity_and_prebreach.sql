-- Quantity of units/product the case concerns, so the {QTY} escalation-template
-- token (already advertised on the admin templates page) actually fills.
alter table cases add column quantity int check (quantity is null or quantity >= 0);

-- Pre-breach SLA warning: fire once ~30 min before an escalation timer expires.
alter table cases add column escalation_prebreach_notified boolean not null default false;

-- Reset both notification flags whenever a case (re-)enters escalated or its timer changes.
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

  if new.status = 'escalated' and old.status is distinct from 'escalated' then
    new.escalated_at := coalesce(new.escalated_at, now());
    new.escalated_by := coalesce(new.escalated_by, auth.uid());
    new.times_escalated := coalesce(old.times_escalated, 0) + 1;
    new.escalation_overdue_notified := false;
    new.escalation_prebreach_notified := false;
    if new.escalation_timer_hours is not null then
      new.escalation_expires_at := new.escalated_at + (new.escalation_timer_hours * interval '1 hour');
    end if;

    insert into escalation_audit (case_id, escalated_by, escalated_at, escalation_reason_id, service_centre_id, timer_hours)
    values (new.id, new.escalated_by, new.escalated_at, new.escalation_reason_id, new.service_centre_id, new.escalation_timer_hours);
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
          was_overdue = (old.escalation_expires_at is not null and now() > old.escalation_expires_at)
      where case_id = new.id and closed_at is null;
  end if;

  if new.status in ('closed', 'resolved') and old.status not in ('closed', 'resolved') then
    new.closed_at := coalesce(new.closed_at, now());
    new.closed_by := coalesce(auth.uid(), new.closed_by, new.assigned_to);
  elsif new.status not in ('closed', 'resolved') and old.status in ('closed', 'resolved') then
    new.closed_at := null;
    new.closed_by := null;
  end if;

  return new;
end;
$$;

-- Warn the assigned agent when an escalation is within 30 minutes of its SLA
-- and hasn't breached yet. Runs on the same 5-minute cron as the overdue check.
create or replace function public.notify_prebreach_escalations()
returns void
security definer
set search_path = public
language plpgsql
as $$
declare
  r record;
begin
  for r in
    select c.id, c.case_number, c.customer_name, c.assigned_to, c.escalation_expires_at
    from cases c
    where c.status = 'escalated'
      and c.assigned_to is not null
      and c.escalation_expires_at is not null
      and c.escalation_expires_at > now()
      and c.escalation_expires_at <= now() + interval '30 minutes'
      and c.escalation_prebreach_notified = false
      and c.escalation_overdue_notified = false
  loop
    insert into notifications (user_id, type, title, body, data)
    values (
      r.assigned_to,
      'escalation_prebreach',
      'Escalation SLA nearly up – case ' || r.case_number,
      format('Case %s (%s) breaches its escalation SLA at %s. React now to stay within SLA.',
        r.case_number, coalesce(r.customer_name, 'unknown customer'),
        to_char(r.escalation_expires_at, 'HH24:MI')),
      jsonb_build_object('case_id', r.id)
    );
    update cases set escalation_prebreach_notified = true where id = r.id;
  end loop;
end;
$$;

revoke execute on function public.notify_prebreach_escalations() from public;

select cron.unschedule(jobid) from cron.job where jobname = 'prebreach-escalation-check';
select cron.schedule('prebreach-escalation-check', '*/5 * * * *', $$select public.notify_prebreach_escalations();$$);
