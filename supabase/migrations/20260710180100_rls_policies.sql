-- Culligan Case Tracker: RLS policies
-- Uses a SECURITY DEFINER helper to avoid self-referencing recursion on profiles policies.

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active = true
  );
$$;

-- ============================================================
-- profiles
-- ============================================================
alter table profiles enable row level security;

create policy "read_own_profile" on profiles for select
  using (auth.uid() = id);

create policy "admins_read_all_profiles" on profiles for select
  using (public.is_admin());

create policy "admins_write_profiles" on profiles for insert
  with check (public.is_admin());

create policy "admins_update_profiles" on profiles for update
  using (public.is_admin());

create policy "users_update_own_profile" on profiles for update
  using (auth.uid() = id);

-- ============================================================
-- lookup tables: everyone authenticated can read, only admins write
-- ============================================================
alter table departments enable row level security;
alter table case_types enable row level security;
alter table service_centres enable row level security;
alter table escalation_reasons enable row level security;
alter table escalation_templates enable row level security;

create policy "authenticated_read_departments" on departments for select
  using (auth.role() = 'authenticated');
create policy "admins_write_departments" on departments for all
  using (public.is_admin()) with check (public.is_admin());

create policy "authenticated_read_case_types" on case_types for select
  using (auth.role() = 'authenticated');
create policy "admins_write_case_types" on case_types for all
  using (public.is_admin()) with check (public.is_admin());

create policy "authenticated_read_service_centres" on service_centres for select
  using (auth.role() = 'authenticated');
create policy "admins_write_service_centres" on service_centres for all
  using (public.is_admin()) with check (public.is_admin());

create policy "authenticated_read_escalation_reasons" on escalation_reasons for select
  using (auth.role() = 'authenticated');
create policy "admins_write_escalation_reasons" on escalation_reasons for all
  using (public.is_admin()) with check (public.is_admin());

create policy "authenticated_read_escalation_templates" on escalation_templates for select
  using (auth.role() = 'authenticated');
create policy "admins_write_escalation_templates" on escalation_templates for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- cases
-- ============================================================
alter table cases enable row level security;

create policy "agents_read_own_cases" on cases for select
  using (assigned_to = auth.uid());
create policy "agents_update_own_cases" on cases for update
  using (assigned_to = auth.uid());
create policy "admins_all_cases" on cases for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- case_notes
-- ============================================================
alter table case_notes enable row level security;

create policy "agents_notes_on_own_cases" on case_notes for all
  using (
    exists (select 1 from cases where cases.id = case_notes.case_id and cases.assigned_to = auth.uid())
  )
  with check (
    exists (select 1 from cases where cases.id = case_notes.case_id and cases.assigned_to = auth.uid())
  );
create policy "admins_all_notes" on case_notes for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- case_mentions
-- ============================================================
alter table case_mentions enable row level security;

create policy "users_read_own_mentions" on case_mentions for select
  using (mentioned_user = auth.uid() or mentioned_by = auth.uid());
create policy "agents_create_mentions_on_own_cases" on case_mentions for insert
  with check (
    exists (select 1 from cases where cases.id = case_mentions.case_id and cases.assigned_to = auth.uid())
  );
create policy "users_update_own_mentions" on case_mentions for update
  using (mentioned_user = auth.uid());
create policy "admins_all_mentions" on case_mentions for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- case_status_history
-- ============================================================
alter table case_status_history enable row level security;

create policy "agents_read_history_own_cases" on case_status_history for select
  using (
    exists (select 1 from cases where cases.id = case_status_history.case_id and cases.assigned_to = auth.uid())
  );
create policy "agents_insert_history_own_cases" on case_status_history for insert
  with check (
    exists (select 1 from cases where cases.id = case_status_history.case_id and cases.assigned_to = auth.uid())
  );
create policy "admins_all_history" on case_status_history for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- reminders
-- ============================================================
alter table reminders enable row level security;

create policy "agents_own_reminders" on reminders for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "admins_all_reminders" on reminders for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- escalation_audit
-- ============================================================
alter table escalation_audit enable row level security;

create policy "agents_read_own_escalation_audit" on escalation_audit for select
  using (
    exists (select 1 from cases where cases.id = escalation_audit.case_id and cases.assigned_to = auth.uid())
  );
create policy "agents_insert_own_escalation_audit" on escalation_audit for insert
  with check (
    exists (select 1 from cases where cases.id = escalation_audit.case_id and cases.assigned_to = auth.uid())
  );
create policy "admins_all_escalation_audit" on escalation_audit for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- email_templates (admin report templates) - admin only
-- ============================================================
alter table email_templates enable row level security;

create policy "admins_email_templates" on email_templates for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- daily_stats
-- ============================================================
alter table daily_stats enable row level security;

create policy "agents_read_own_stats" on daily_stats for select
  using (agent_id = auth.uid());
create policy "admins_all_stats" on daily_stats for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- agent_mood_log
-- ============================================================
alter table agent_mood_log enable row level security;

create policy "agents_own_mood" on agent_mood_log for all
  using (agent_id = auth.uid()) with check (agent_id = auth.uid());
create policy "admins_read_all_mood" on agent_mood_log for select
  using (public.is_admin());

-- ============================================================
-- audit_log - admin only
-- ============================================================
alter table audit_log enable row level security;

create policy "admins_read_audit_log" on audit_log for select
  using (public.is_admin());
create policy "system_insert_audit_log" on audit_log for insert
  with check (auth.role() = 'authenticated');
