-- Performance advisor fixes.
--
-- 1) auth_rls_initplan: policies calling auth.uid()/auth.role() directly get re-evaluated
--    per row instead of once per query. Wrapping the call as (select auth.uid()) lets
--    Postgres treat it as a stable initplan, evaluated once. Pure is_admin()-only policies
--    were not flagged (the function itself already does this internally) and are untouched.
-- 2) unindexed_foreign_keys: adds covering indexes for FK columns used in joins/filters.

-- ============================================================
-- profiles
-- ============================================================
alter policy "authenticated_read_profiles" on profiles
  using ((select auth.role()) = 'authenticated');
alter policy "read_own_profile" on profiles
  using ((select auth.uid()) = id);
alter policy "users_update_own_profile" on profiles
  using ((select auth.uid()) = id);

-- ============================================================
-- lookup tables
-- ============================================================
alter policy "authenticated_read_departments" on departments
  using ((select auth.role()) = 'authenticated');
alter policy "authenticated_read_case_types" on case_types
  using ((select auth.role()) = 'authenticated');
alter policy "authenticated_read_service_centres" on service_centres
  using ((select auth.role()) = 'authenticated');
alter policy "authenticated_read_escalation_reasons" on escalation_reasons
  using ((select auth.role()) = 'authenticated');
alter policy "authenticated_read_escalation_templates" on escalation_templates
  using ((select auth.role()) = 'authenticated');
alter policy "authenticated_read_org_settings" on org_settings
  using ((select auth.role()) = 'authenticated');

-- ============================================================
-- cases
-- ============================================================
alter policy "agents_create_own_cases" on cases
  with check (assigned_to = (select auth.uid()));
alter policy "agents_read_own_cases" on cases
  using (assigned_to = (select auth.uid()));
alter policy "agents_update_own_cases" on cases
  using (assigned_to = (select auth.uid()));

-- ============================================================
-- case_notes
-- ============================================================
alter policy "agents_notes_on_own_cases" on case_notes
  using (exists (select 1 from cases where cases.id = case_notes.case_id and cases.assigned_to = (select auth.uid())))
  with check (exists (select 1 from cases where cases.id = case_notes.case_id and cases.assigned_to = (select auth.uid())));

-- ============================================================
-- case_mentions
-- ============================================================
alter policy "agents_create_mentions_on_own_cases" on case_mentions
  with check (exists (select 1 from cases where cases.id = case_mentions.case_id and cases.assigned_to = (select auth.uid())));
alter policy "users_read_own_mentions" on case_mentions
  using (mentioned_user = (select auth.uid()) or mentioned_by = (select auth.uid()));
alter policy "users_update_own_mentions" on case_mentions
  using (mentioned_user = (select auth.uid()));

-- ============================================================
-- case_status_history
-- ============================================================
alter policy "agents_read_history_own_cases" on case_status_history
  using (exists (select 1 from cases where cases.id = case_status_history.case_id and cases.assigned_to = (select auth.uid())));
alter policy "agents_insert_history_own_cases" on case_status_history
  with check (exists (select 1 from cases where cases.id = case_status_history.case_id and cases.assigned_to = (select auth.uid())));

-- ============================================================
-- reminders
-- ============================================================
alter policy "agents_own_reminders" on reminders
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ============================================================
-- escalation_audit
-- ============================================================
alter policy "agents_read_own_escalation_audit" on escalation_audit
  using (exists (select 1 from cases where cases.id = escalation_audit.case_id and cases.assigned_to = (select auth.uid())));
alter policy "agents_insert_own_escalation_audit" on escalation_audit
  with check (exists (select 1 from cases where cases.id = escalation_audit.case_id and cases.assigned_to = (select auth.uid())));

-- ============================================================
-- daily_stats
-- ============================================================
alter policy "agents_read_own_stats" on daily_stats
  using (agent_id = (select auth.uid()));

-- ============================================================
-- agent_mood_log
-- ============================================================
alter policy "agents_own_mood" on agent_mood_log
  using (agent_id = (select auth.uid()))
  with check (agent_id = (select auth.uid()));

-- ============================================================
-- audit_log
-- ============================================================
alter policy "system_insert_audit_log" on audit_log
  with check ((select auth.role()) = 'authenticated');

-- ============================================================
-- notifications
-- ============================================================
alter policy "users_read_own_notifications" on notifications
  using (user_id = (select auth.uid()));
alter policy "users_update_own_notifications" on notifications
  using (user_id = (select auth.uid()));

-- ============================================================
-- Missing FK covering indexes
-- ============================================================
create index if not exists idx_audit_log_actor_id on audit_log(actor_id);
create index if not exists idx_case_mentions_case_id on case_mentions(case_id);
create index if not exists idx_case_mentions_mentioned_by on case_mentions(mentioned_by);
create index if not exists idx_case_mentions_note_id on case_mentions(note_id);
create index if not exists idx_case_notes_user_id on case_notes(user_id);
create index if not exists idx_case_status_history_changed_by on case_status_history(changed_by);
create index if not exists idx_cases_case_type_id on cases(case_type_id);
create index if not exists idx_cases_escalated_by on cases(escalated_by);
create index if not exists idx_cases_escalation_reason_id on cases(escalation_reason_id);
create index if not exists idx_cases_service_centre_id on cases(service_centre_id);
create index if not exists idx_email_templates_created_by on email_templates(created_by);
create index if not exists idx_escalation_audit_closed_by on escalation_audit(closed_by);
create index if not exists idx_escalation_audit_escalated_by on escalation_audit(escalated_by);
create index if not exists idx_escalation_audit_escalation_reason_id on escalation_audit(escalation_reason_id);
create index if not exists idx_escalation_audit_service_centre_id on escalation_audit(service_centre_id);
create index if not exists idx_escalation_templates_created_by on escalation_templates(created_by);
create index if not exists idx_profiles_department_id on profiles(department_id);
create index if not exists idx_reminders_case_id on reminders(case_id);
