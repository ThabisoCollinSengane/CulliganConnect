-- Simple teams: team leaders (admins) create a team and put agents in it, to
-- separate their people. Not a permissions boundary — just a grouping label.
create table teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  team_leader_id uuid references profiles(id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table profiles add column team_id uuid references teams(id) on delete set null;

alter table teams enable row level security;
create policy "authenticated_read_teams" on teams for select
  using ((select auth.role()) = 'authenticated');
create policy "admins_write_teams" on teams for all
  using (is_admin()) with check (is_admin());

-- Temporary onboarding passwords, visible to admins until the agent changes theirs.
-- Deliberately admin-visible plaintext for internal onboarding only; the row is
-- deleted the moment the agent sets their own password (see agent/settings.html).
create table agent_onboarding (
  profile_id uuid primary key references profiles(id) on delete cascade,
  temp_password text not null,
  created_at timestamptz not null default now()
);

alter table agent_onboarding enable row level security;
create policy "admins_read_onboarding" on agent_onboarding for select
  using (is_admin());
create policy "owner_read_onboarding" on agent_onboarding for select
  using (profile_id = (select auth.uid()));
create policy "admins_write_onboarding" on agent_onboarding for all
  using (is_admin()) with check (is_admin());
create policy "owner_delete_onboarding" on agent_onboarding for delete
  using (profile_id = (select auth.uid()));
