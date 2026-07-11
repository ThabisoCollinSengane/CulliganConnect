-- Agent-side features: personal templates, a notepad, call logging, and targets.

-- ============================================================
-- Email templates: admin-created ones are shared/default; agents can add
-- their own personal ones nobody else sees.
-- ============================================================
alter table email_templates add column is_shared boolean not null default true;

create or replace function public.enforce_email_template_sharing()
returns trigger
security definer
set search_path = public
language plpgsql
as $$
begin
  if not public.is_admin() then
    new.is_shared := false;
  end if;
  return new;
end;
$$;

create trigger trg_10_email_templates_sharing
  before insert or update on email_templates
  for each row execute function public.enforce_email_template_sharing();

revoke execute on function public.enforce_email_template_sharing() from public;

drop policy "authenticated_read_email_templates" on email_templates;

create policy "read_shared_or_own_templates" on email_templates for select
  using (is_shared = true or created_by = (select auth.uid()));
create policy "agents_insert_own_templates" on email_templates for insert
  with check (created_by = (select auth.uid()));
create policy "agents_update_own_templates" on email_templates for update
  using (created_by = (select auth.uid()) and is_shared = false);
create policy "agents_delete_own_templates" on email_templates for delete
  using (created_by = (select auth.uid()) and is_shared = false);

-- ============================================================
-- Quick notes: a personal notepad, not tied to any case.
-- ============================================================
create table quick_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  note text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_quick_notes_user on quick_notes(user_id);

alter table quick_notes enable row level security;

create policy "agents_own_quick_notes" on quick_notes for all
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "admins_all_quick_notes" on quick_notes for all
  using (is_admin()) with check (is_admin());

create trigger trg_90_quick_notes_updated_at
  before update on quick_notes
  for each row execute function public.set_updated_at();

-- ============================================================
-- Call logs: how many calls an agent took on a given day.
-- ============================================================
create table call_logs (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references profiles(id) on delete cascade,
  call_date date not null default current_date,
  calls_taken int not null default 0 check (calls_taken >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (agent_id, call_date)
);

create index idx_call_logs_agent_date on call_logs(agent_id, call_date);

alter table call_logs enable row level security;

create policy "agents_own_call_logs" on call_logs for all
  using (agent_id = (select auth.uid())) with check (agent_id = (select auth.uid()));
create policy "admins_all_call_logs" on call_logs for all
  using (is_admin()) with check (is_admin());

create trigger trg_90_call_logs_updated_at
  before update on call_logs
  for each row execute function public.set_updated_at();

-- ============================================================
-- Targets: agents set their own; admins can set one for a specific agent
-- or a team-wide target (agent_id null).
-- ============================================================
create table targets (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid references profiles(id) on delete cascade,
  period text not null check (period in ('day', 'week', 'month')),
  metric text not null check (metric in ('cases_closed', 'cases_interacted', 'calls_taken')),
  target_value int not null check (target_value > 0),
  period_start date not null default current_date,
  created_by uuid references profiles(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_targets_agent on targets(agent_id, is_active);

alter table targets enable row level security;

create policy "agents_manage_own_targets" on targets for all
  using (agent_id = (select auth.uid())) with check (agent_id = (select auth.uid()));
create policy "agents_read_team_targets" on targets for select
  using (agent_id is null and is_active = true and (select auth.role()) = 'authenticated');
create policy "admins_all_targets" on targets for all
  using (is_admin()) with check (is_admin());

create trigger trg_90_targets_updated_at
  before update on targets
  for each row execute function public.set_updated_at();
