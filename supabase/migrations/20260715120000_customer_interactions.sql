-- Customer interaction tracking: log customer contacts that don't spawn a full
-- case (swaps, quick enquiries, account updates). Captures the full picture of
-- agent workload and per-account contact history that the cases table misses.

-- ============================================================
-- Interaction types: an admin-configurable lookup, exactly like case_types —
-- admins add/deactivate types without a code change. Deactivate (is_active =
-- false) rather than delete, so historical interactions keep their type.
-- ============================================================
create table interaction_types (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table interaction_types enable row level security;

create policy authenticated_read_interaction_types on interaction_types for select
  using ((select auth.role()) = 'authenticated');
create policy admins_write_interaction_types on interaction_types for all
  using (is_admin()) with check (is_admin());

insert into interaction_types (name) values
  ('Swap'),
  ('General enquiry'),
  ('Account update'),
  ('Delivery query'),
  ('Complaint'),
  ('Billing query');

-- ============================================================
-- Customer interactions: one row per logged contact. account_number is the
-- link back to a customer (cases carry the same free-text account_number).
-- case_id optionally ties an interaction to a case it relates to.
-- ============================================================
create table customer_interactions (
  id uuid primary key default gen_random_uuid(),
  account_number text,
  interaction_type_id uuid not null references interaction_types(id) on delete restrict,
  notes text,
  case_id uuid references cases(id) on delete set null,
  agent_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index idx_customer_interactions_account on customer_interactions(account_number);
create index idx_customer_interactions_agent on customer_interactions(agent_id);
create index idx_customer_interactions_case on customer_interactions(case_id);
create index idx_customer_interactions_created on customer_interactions(created_at);

alter table customer_interactions enable row level security;

-- Team-readable (same as case_notes): admin reporting needs every agent's
-- interactions, and the case page shows an account's recent contacts
-- regardless of who logged them. Agents write/edit/remove only their own.
create policy agents_read_all_interactions on customer_interactions for select
  using ((select auth.role()) = 'authenticated');
create policy agents_insert_own_interactions on customer_interactions for insert
  with check (agent_id = (select auth.uid()));
create policy agents_update_own_interactions on customer_interactions for update
  using (agent_id = (select auth.uid())) with check (agent_id = (select auth.uid()));
create policy agents_delete_own_interactions on customer_interactions for delete
  using (agent_id = (select auth.uid()));
create policy admins_all_interactions on customer_interactions for all
  using (is_admin()) with check (is_admin());
