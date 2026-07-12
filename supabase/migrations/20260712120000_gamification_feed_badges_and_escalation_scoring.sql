-- Activity feed: a lightweight, company-wide "who did what" ticker for the
-- agent dashboard. No customer data — just case numbers and badge labels.
create table activity_feed (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references profiles(id) on delete set null,
  type text not null check (type in ('case_closed', 'badge')),
  case_number text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index idx_activity_feed_created on activity_feed(created_at desc);

alter table activity_feed enable row level security;
create policy "authenticated_read_activity_feed" on activity_feed for select
  using ((select auth.role()) = 'authenticated');
-- 'case_closed' rows only ever come from the trigger below (security definer,
-- bypasses RLS); clients can only insert their own 'badge' announcements.
create policy "agents_insert_own_badge_activity" on activity_feed for insert
  with check (actor_id = (select auth.uid()) and type = 'badge');

alter publication supabase_realtime add table activity_feed;

-- Persisted, collectible achievements. Client computes eligibility and
-- inserts (unique constraint makes it idempotent); visible team-wide so
-- badges are something to show off, not just a private stat.
create table badges (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references profiles(id) on delete cascade,
  badge_key text not null,
  label text not null,
  earned_at timestamptz not null default now(),
  unique (agent_id, badge_key)
);
create index idx_badges_agent on badges(agent_id);

alter table badges enable row level security;
create policy "authenticated_read_badges" on badges for select
  using ((select auth.role()) = 'authenticated');
create policy "agents_insert_own_badges" on badges for insert
  with check (agent_id = (select auth.uid()));

-- Widen escalation_audit read to team-wide, matching the shared-queue model
-- already used for cases/case_notes/case_status_history since the "team case
-- visibility" migration. No customer PII in this table (case_id, timer info,
-- was_overdue, closed_by) — needed so leaderboards can factor escalation
-- quality across ALL agents, not just the viewer's own cases.
drop policy "agents_read_own_escalation_audit" on escalation_audit;
create policy "agents_read_all_escalation_audit" on escalation_audit for select
  using ((select auth.role()) = 'authenticated');

-- Extend the case-close trigger to drop a "case closed" event into the feed.
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
  end if;

  return new;
end;
$$;

-- escalation_audit.closed_by was never populated by the trigger before this
-- migration — a real, previously-undiscovered gap found while wiring
-- escalation quality into leaderboard scoring. Backfill existing rows from
-- the case's closed_by (fallback to who raised the escalation).
update escalation_audit ea
set closed_by = coalesce(c.closed_by, ea.escalated_by)
from cases c
where c.id = ea.case_id and ea.closed_at is not null and ea.closed_by is null;
