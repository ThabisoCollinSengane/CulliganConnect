-- Notify assigned agents + admins when an escalated case blows past its SLA timer.
-- A pg_cron job checks every 5 minutes and fires an in-app + browser-push notification once per breach.

alter table cases add column escalation_overdue_notified boolean not null default false;

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
  end if;

  if old.status = 'escalated' and new.status is distinct from 'escalated' then
    update escalation_audit
      set closed_at = now(),
          was_overdue = (old.escalation_expires_at is not null and now() > old.escalation_expires_at)
      where case_id = new.id and closed_at is null;
  end if;

  if new.status in ('closed', 'resolved') and old.status not in ('closed', 'resolved') then
    new.closed_at := coalesce(new.closed_at, now());
  elsif new.status not in ('closed', 'resolved') and old.status in ('closed', 'resolved') then
    new.closed_at := null;
  end if;

  return new;
end;
$$;

create or replace function public.notify_overdue_escalations()
returns void
security definer
set search_path = public
language plpgsql
as $$
declare
  r record;
  v_title text;
  v_body text;
begin
  for r in
    select c.id, c.case_number, c.customer_name, c.assigned_to, p.full_name as agent_name
    from cases c
    left join profiles p on p.id = c.assigned_to
    where c.status = 'escalated'
      and c.escalation_expires_at is not null
      and c.escalation_expires_at < now()
      and c.escalation_overdue_notified = false
  loop
    v_title := 'Escalation overdue – case ' || r.case_number;
    v_body := format(
      'Case %s (%s) assigned to %s has gone past its escalation SLA.',
      r.case_number,
      coalesce(r.customer_name, 'unknown customer'),
      coalesce(r.agent_name, 'nobody')
    );

    if r.assigned_to is not null then
      insert into notifications (user_id, type, title, body, data)
      values (r.assigned_to, 'escalation_overdue', v_title, v_body, jsonb_build_object('case_id', r.id));
    end if;

    -- Admins get it too, unless they're also the assigned agent (already notified above).
    insert into notifications (user_id, type, title, body, data)
    select p.id, 'escalation_overdue', v_title, v_body, jsonb_build_object('case_id', r.id)
    from profiles p
    where p.role = 'admin' and p.is_active = true and p.id is distinct from r.assigned_to;

    update cases set escalation_overdue_notified = true where id = r.id;
  end loop;
end;
$$;

revoke execute on function public.notify_overdue_escalations() from public;

select cron.unschedule(jobid) from cron.job where jobname = 'overdue-escalation-check';
select cron.schedule('overdue-escalation-check', '*/5 * * * *', $$select public.notify_overdue_escalations();$$);
