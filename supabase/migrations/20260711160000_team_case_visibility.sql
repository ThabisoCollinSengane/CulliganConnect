-- The Excel tracker this replaces was a shared sheet: every agent saw every
-- escalation and anyone could action one when the depot responded. Mirror that:
-- team-wide read, and agents can update their own cases OR any escalated case
-- (which is what makes closing an escalation possible for whoever picks it up).

drop policy "agents_read_own_cases" on cases;
create policy "agents_read_all_cases" on cases for select
  using ((select auth.role()) = 'authenticated');

drop policy "agents_update_own_cases" on cases;
create policy "agents_update_own_or_escalated" on cases for update
  using (assigned_to = (select auth.uid()) or status = 'escalated')
  with check ((select auth.role()) = 'authenticated');

-- Notes: team-readable; any agent can add a note as themselves to any case
-- they can see (tagged colleagues need this to actually give input).
drop policy "agents_notes_on_own_cases" on case_notes;
create policy "agents_read_all_notes" on case_notes for select
  using ((select auth.role()) = 'authenticated');
create policy "agents_insert_own_notes" on case_notes for insert
  with check (user_id = (select auth.uid()));

-- Mentions: any agent can tag a colleague from any case, not just their own.
drop policy "agents_create_mentions_on_own_cases" on case_mentions;
create policy "agents_create_mentions" on case_mentions for insert
  with check (mentioned_by = (select auth.uid()));

-- Status history: team-readable, so a shared case's timeline renders.
drop policy "agents_read_history_own_cases" on case_status_history;
create policy "agents_read_all_history" on case_status_history for select
  using ((select auth.role()) = 'authenticated');
