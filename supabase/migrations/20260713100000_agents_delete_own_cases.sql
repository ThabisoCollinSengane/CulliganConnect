-- Agents can now bulk-delete cases from their own list (agent/cases.html).
-- Scoped to cases assigned to them, same ownership boundary already used for
-- agents_update_own_escalated_or_unassigned -- admins already have full
-- delete access via admins_all_cases.
create policy agents_delete_own_cases on cases for delete
  using (assigned_to = (select auth.uid()));
