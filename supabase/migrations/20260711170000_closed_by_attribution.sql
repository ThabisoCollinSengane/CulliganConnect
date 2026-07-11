-- Credit whoever actually closes a case, not the assignee. Matters now that
-- escalated cases are a shared queue anyone can close.
alter table cases add column closed_by uuid references profiles(id);
create index idx_cases_closed_by on cases(closed_by, closed_at);

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
    new.closed_by := coalesce(auth.uid(), new.closed_by, new.assigned_to);
  elsif new.status not in ('closed', 'resolved') and old.status in ('closed', 'resolved') then
    new.closed_at := null;
    new.closed_by := null;
  end if;

  return new;
end;
$$;

-- Backfill: latest close/resolve transition in history wins; fall back to assignee.
update cases c
set closed_by = coalesce(
  (select h.changed_by from case_status_history h
    where h.case_id = c.id and h.new_status in ('closed','resolved')
    order by h.changed_at desc limit 1),
  c.assigned_to)
where c.status in ('closed','resolved') and c.closed_by is null;

-- Agents can also claim unassigned cases ("Assign to me").
drop policy "agents_update_own_or_escalated" on cases;
create policy "agents_update_own_escalated_or_unassigned" on cases for update
  using (assigned_to = (select auth.uid()) or status = 'escalated' or assigned_to is null)
  with check ((select auth.role()) = 'authenticated');
