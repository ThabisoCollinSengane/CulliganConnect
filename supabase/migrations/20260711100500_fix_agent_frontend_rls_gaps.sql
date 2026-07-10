-- Agents need to create cases they're logging themselves (manual entry, not just admin assignment).
create policy "agents_create_own_cases" on cases for insert
  with check (assigned_to = auth.uid());

-- All signed-in staff can see each other's names (small internal team; needed for note
-- attribution, @mention tagging, and case history display). Data stays gated elsewhere by RLS.
create policy "authenticated_read_profiles" on profiles for select
  using (auth.role() = 'authenticated');
