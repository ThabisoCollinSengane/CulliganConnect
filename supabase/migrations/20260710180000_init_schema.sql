-- Culligan Case Tracker: core schema
-- Extensions
create extension if not exists "pgcrypto";

-- ============================================================
-- Lookup / admin-configurable tables
-- ============================================================

create table departments (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table case_types (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Depots / service centres a case can be escalated to (from the UK service centre directory)
create table service_centres (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,           -- e.g. UK112
  name text not null,                  -- e.g. UK112- Peterborough
  town text,
  regional_manager text,
  depot_email text not null,
  cc_contacts text,                    -- semicolon-separated list, kept simple for MVP
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table escalation_reasons (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,           -- e.g. "Over SLA - Water Delivery"
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ============================================================
-- People
-- ============================================================

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  full_name text not null,
  role text not null default 'agent' check (role in ('agent', 'admin')),
  department_id uuid references departments(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================
-- Cases
-- ============================================================

create table cases (
  id uuid primary key default gen_random_uuid(),
  case_number text unique not null,
  account_number text,
  task_number text,
  work_order_number text,
  customer_name text,
  customer_phone text,
  customer_email text,
  case_type_id uuid references case_types(id),
  status text not null default 'new'
    check (status in ('new', 'pending', 'escalated', 'awaiting_response', 'resolved', 'closed')),
  priority text not null default 'normal' check (priority in ('normal', 'high', 'urgent')),
  assigned_to uuid references profiles(id),
  department_id uuid references departments(id),   -- denormalised from assigned agent, for filtering

  -- Escalation
  service_centre_id uuid references service_centres(id),
  escalation_reason_id uuid references escalation_reasons(id),
  escalated_by uuid references profiles(id),
  escalated_at timestamptz,
  escalation_timer_hours numeric(5, 2),
  escalation_expires_at timestamptz,
  times_escalated int not null default 0,
  callback_arranged text,

  notes text,   -- last note summary, denormalised for list views
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  sla_date date,
  source text not null default 'salesforce'
);

create index idx_cases_assigned_to on cases(assigned_to);
create index idx_cases_status on cases(status);
create index idx_cases_department on cases(department_id);
create index idx_cases_escalation_expires on cases(escalation_expires_at) where status = 'escalated';
create index idx_cases_account_number on cases(account_number);
create index idx_cases_sla_date on cases(sla_date);

create table case_notes (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references cases(id) on delete cascade,
  user_id uuid references profiles(id),
  note text not null,
  note_type text not null default 'internal' check (note_type in ('internal', 'customer')),
  created_at timestamptz not null default now()
);

create index idx_case_notes_case_id on case_notes(case_id);

-- @Mentions / tagging colleagues for input on a case
create table case_mentions (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references cases(id) on delete cascade,
  note_id uuid references case_notes(id) on delete cascade,
  mentioned_by uuid references profiles(id),
  mentioned_user uuid not null references profiles(id),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_case_mentions_user on case_mentions(mentioned_user, is_read);

create table case_status_history (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references cases(id) on delete cascade,
  old_status text,
  new_status text,
  changed_by uuid references profiles(id),
  changed_at timestamptz not null default now()
);

create index idx_case_status_history_case_id on case_status_history(case_id);

create table reminders (
  id uuid primary key default gen_random_uuid(),
  case_id uuid references cases(id) on delete cascade,
  user_id uuid not null references profiles(id),
  reminder_at timestamptz not null,
  note text,
  is_dismissed boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_reminders_user on reminders(user_id, is_dismissed);

create table escalation_audit (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references cases(id) on delete cascade,
  escalated_by uuid references profiles(id),
  escalated_at timestamptz not null default now(),
  escalation_reason_id uuid references escalation_reasons(id),
  service_centre_id uuid references service_centres(id),
  timer_hours numeric(5, 2),
  expired_at timestamptz,
  was_overdue boolean not null default false,
  closed_at timestamptz,
  closed_by uuid references profiles(id)
);

create index idx_escalation_audit_case on escalation_audit(case_id);

-- Per-escalation-reason email templates (depot + customer), replacing {TOKENS}
create table escalation_templates (
  id uuid primary key default gen_random_uuid(),
  escalation_reason_id uuid unique not null references escalation_reasons(id),
  depot_subject text not null,
  depot_body text not null,
  customer_subject text,
  customer_body text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Admin performance-report email templates (distinct from escalation_templates above)
create table email_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  subject text not null,
  body text not null,
  category text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table daily_stats (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references profiles(id),
  date date not null,
  cases_created int not null default 0,
  cases_closed int not null default 0,
  cases_interacted int not null default 0,
  escalated_count int not null default 0,
  awaiting_response int not null default 0,
  avg_response_time_hours numeric(5, 2),
  avg_resolution_time_hours numeric(5, 2),
  sla_breach_count int not null default 0,
  created_at timestamptz not null default now(),
  unique (agent_id, date)
);

create index idx_daily_stats_agent_date on daily_stats(agent_id, date);

-- Daily agent mood check-in (self-reported, private sentiment signal for admins)
create table agent_mood_log (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references profiles(id),
  mood text not null check (mood in ('great', 'good', 'okay', 'stressed', 'overwhelmed')),
  note text,
  logged_at date not null default current_date,
  created_at timestamptz not null default now(),
  unique (agent_id, logged_at)
);

create table audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  detail jsonb,
  created_at timestamptz not null default now()
);

create index idx_audit_log_entity on audit_log(entity_type, entity_id);
