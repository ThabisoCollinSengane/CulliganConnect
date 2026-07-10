Culligan Case Tracker – Project Memory

🎯 Project Overview

We are building an internal case management and performance tracking tool for a Culligan water call centre. The tool replaces multiple external tools (notes, email templates, spreadsheets) with a single, all-in-one platform.

Purpose:

· Track cases from creation to resolution
· Monitor agent performance with real-time stats
· Manage escalations with timers and SLA tracking
· Provide admins with full visibility and reporting
· Boost agent productivity and call centre performance

Primary Users:

1. Agents – handle cases, log notes, track escalations, view personal stats
2. Admins (Team Leaders) – manage agents, view team stats, assign cases, generate reports

---

📊 Core Features (Complete List)

Agent Features

· Login with admin‑created credentials (email + password)
· Personal dashboard with stats (calendar date picker)
· View assigned cases (search/filter)
· Case detail with notes, status, timeline
· Add notes (internal/customer-facing)
· Update case status (Open, Escalated, Closed, Awaiting Response)
· Set escalation timer (1h, 3h, 8h, 24h, custom)
· Set reminders on cases (date/time + note)
· View SLA countdown on escalated cases
· Copy email templates (admin-created library)
· @Mentions in notes
· Browser notifications
· "My Day" priority list
· Quick Notes (sidebar, no full case view needed)
· Auto‑save notes (every 30 seconds)
· Keyboard shortcuts

Admin Features

· Login with credentials
· Team dashboard with agent stats
· View agents by department
· Rank agents by performance (closures, interactions, weighted score)
· Filter stats by department, case type, date range
· Create/manage agents (add, disable, reset password)
· Assign cases to agents (single/bulk)
· Manage departments (add/edit/remove)
· Manage case types (Water Order, Service Request, Swap, Account Updates)
· Manage email templates (create/edit/delete)
· Generate performance email reports (copy to Outlook/Teams)
· View escalation risk (overdue escalations)
· Export reports (CSV/PDF)
· Audit log (view all agent actions)

---

🗄️ Database Schema (Supabase)

Table: profiles

```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  email TEXT UNIQUE,
  full_name TEXT,
  role TEXT DEFAULT 'agent', -- 'agent' or 'admin'
  department TEXT, -- Sales, Customer Service, Tech, Retention, Onboarding
  team TEXT, -- optional team/sub-team
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

Table: cases

```sql
CREATE TABLE cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_number TEXT UNIQUE NOT NULL, -- e.g. 00248484
  account_number TEXT,
  task_number TEXT,
  customer_name TEXT,
  customer_phone TEXT,
  customer_email TEXT,
  case_type TEXT, -- Water Order, Service Request, Swap, Account Updates
  status TEXT DEFAULT 'new', -- new, pending, escalated, awaiting_response, closed
  priority TEXT DEFAULT 'normal', -- normal, high, urgent
  assigned_to UUID REFERENCES profiles(id),
  escalated_by UUID REFERENCES profiles(id),
  escalated_at TIMESTAMPTZ,
  escalation_timer_hours INT, -- 1, 3, 8, 24, custom
  escalation_expires_at TIMESTAMPTZ,
  notes TEXT, -- last note summary
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  closed_at TIMESTAMPTZ,
  sla_date DATE,
  source TEXT DEFAULT 'salesforce',
  department TEXT -- department of assigned agent (denormalised for filtering)
);
```

Table: case_notes

```sql
CREATE TABLE case_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID REFERENCES cases(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id),
  note TEXT NOT NULL,
  note_type TEXT DEFAULT 'internal', -- internal or customer
  created_at TIMESTAMPTZ DEFAULT now()
);
```

Table: case_status_history

```sql
CREATE TABLE case_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID REFERENCES cases(id) ON DELETE CASCADE,
  old_status TEXT,
  new_status TEXT,
  changed_by UUID REFERENCES profiles(id),
  changed_at TIMESTAMPTZ DEFAULT now()
);
```

Table: email_templates

```sql
CREATE TABLE email_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  category TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

Table: reminders

```sql
CREATE TABLE reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID REFERENCES cases(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id),
  reminder_at TIMESTAMPTZ NOT NULL,
  note TEXT,
  is_dismissed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

Table: escalation_audit

```sql
CREATE TABLE escalation_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID REFERENCES cases(id) ON DELETE CASCADE,
  escalated_by UUID REFERENCES profiles(id),
  escalated_at TIMESTAMPTZ DEFAULT now(),
  timer_hours INT,
  expired_at TIMESTAMPTZ,
  was_overdue BOOLEAN DEFAULT false
);
```

Table: daily_stats (aggregated for performance)

```sql
CREATE TABLE daily_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID REFERENCES profiles(id),
  date DATE NOT NULL,
  cases_created INT DEFAULT 0,
  cases_closed INT DEFAULT 0,
  cases_interacted INT DEFAULT 0, -- any case with new note/status change
  escalated_count INT DEFAULT 0,
  awaiting_response INT DEFAULT 0,
  avg_response_time_hours DECIMAL(5,2),
  avg_resolution_time_hours DECIMAL(5,2),
  sla_breach_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

---

🔐 Authentication & RLS Policies

Auth

· Email/password only – no Google login
· Admin creates user credentials via admin panel
· Default admin:
  · Username: thacollin2@gmail.com
  · Password: set separately via Supabase Auth (not committed to the repo)
· Supabase sends no confirmation email (password is set by admin)

RLS Policies

```sql
-- Profiles: users can read own, admins can read all
CREATE POLICY "read_own_profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "admins_read_all_profiles" ON profiles FOR SELECT USING (
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);

-- Cases: agents see own, admins see all
CREATE POLICY "agents_own_cases" ON cases FOR SELECT USING (assigned_to = auth.uid());
CREATE POLICY "admins_all_cases" ON cases FOR ALL USING (
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);

-- Case Notes: agents on their cases, admins all
CREATE POLICY "agents_own_notes" ON case_notes FOR ALL USING (
  (SELECT assigned_to FROM cases WHERE id = case_notes.case_id) = auth.uid()
);
CREATE POLICY "admins_all_notes" ON case_notes FOR ALL USING (
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);

-- Reminders: agents own, admins all
CREATE POLICY "agents_own_reminders" ON reminders FOR ALL USING (user_id = auth.uid());
CREATE POLICY "admins_all_reminders" ON reminders FOR ALL USING (
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);

-- Templates: admins only
CREATE POLICY "admins_templates" ON email_templates FOR ALL USING (
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);
```

---

🎨 UI Theme – Blue (Culligan Water)

Colour Palette

Colour Hex Use
Primary Blue #0033A0 Headers, buttons
Light Blue #E8F0FE Backgrounds, cards
Accent Blue #0072CE Links, highlights
Dark Blue #002266 Text
White #FFFFFF Cards, fields
Red #D32F2F Alerts, overdue
Green #2E7D32 Closed, on‑time
Orange #F57C00 Pending escalations

Design Principles

· Clean, corporate, professional
· Cards with subtle shadows
· Blue gradients on headers
· Mobile-first (agents use phones)
· Inspired by Salesforce/Zendesk layout

---

🏢 Departments (Admin Configurable)

Department Description
Sales New business, quotes, upsells
Customer Service General inquiries, complaints
Tech Department Dispensers, repairs, installs
Retention Cancellations, retention offers
Onboarding New customer setups

---

📊 Performance Metrics & Ranking

Agent Metrics

Metric Calculation
Cases Closed Total closed (simple count)
Cases Interacted Any case with note or status update
Response Time Avg time from assignment to first note
Resolution Time Avg time from creation to closure
Escalation Rate % of cases escalated (lower is better)
SLA Breach Rate % of cases missing SLA deadline

Ranking Types (Admin Selectable)

1. Cases Closed – most common
2. Cases Interacted – measures overall engagement
3. Weighted Score – (Closed × 2) + (Interacted × 1)
4. Department Weighted – custom weights per department

Ranking Filters

· Department
· Case Type (Water Order, Service Request, Swap, Account Updates)
· Date Range (Today, Week, Month, Custom)
· Status
· Agent (individual)

---

⏱️ Escalation Life Period

Flow

1. Agent escalates case → prompted to set timer:
   · Pre‑set: 1h, 3h, 8h, 24h, 48h
   · Or custom time
2. Timer starts → countdown visible on case card:
   · 🟢 Safe: > 50% remaining
   · 🟡 Warning: < 25% remaining
   · 🔴 Overdue: timer expired
3. When expired:
   · Case turns red
   · Browser notification + email
   · Escalation flagged for admin

Admin View

· "Escalation Risk" column:
  · 🟢 Not escalated
  · 🟡 Escalated – within time
  · 🔴 Overdue

---

📧 Admin Email Template Generator

Templates Available

1. Weekly Performance Summary
2. Monthly Review
3. SLA Report
4. Team Ranking

Generation Process

1. Admin selects date range
2. Admin selects department (or All)
3. Admin selects metrics to include
4. System generates formatted email:
   · Table with stats per agent
   · Summary paragraph
   · Top performers highlighted
5. Admin clicks "Copy to Clipboard" → paste into Outlook/Teams

Example Output

```
Subject: Weekly Performance Summary – Customer Service Team (Week 25)

📊 Team Overview:
- Total cases closed: 142
- Avg response time: 2.3h
- Escalation rate: 8%
- SLA breach rate: 3%

🏆 Top Performer (Closures): Asanda Gumenke – 34 cases closed
🏆 Top Performer (Interactions): Thabiso Sengane – 89 case interactions

Agent Breakdown:
| Agent | Closed | Interacted | Avg Response | Escalations |
|-------|--------|------------|---------------|-------------|
| Asanda G | 34 | 72 | 1.8h | 2 |
| Thabiso S | 28 | 89 | 2.1h | 3 |
```

---

🛠️ Tech Stack

Layer Technology
Frontend Vanilla HTML/CSS/JS (or React if migrating)
Backend Vercel serverless API (api/index.js)
Database Supabase (PostgreSQL + Auth + RLS)
Auth Supabase Auth (email/password)
Hosting Vercel
Payments Not applicable (internal tool)
Analytics Custom dashboards (no external)

---

🚀 Implementation Roadmap

Phase 1 – Database & Auth (Week 1)

· Supabase project setup
· Tables: profiles, cases, case_notes, status_history, templates, reminders, escalation_audit, daily_stats
· RLS policies
· Auth (email/password) with admin-created users
· Default admin user (thacollin2@gmail.com)
· Admin panel for user creation

Phase 2 – Agent Features (Week 2)

· Login screen
· Agent dashboard (stats with date picker)
· Case list (search/filter)
· Case detail view (notes, status, timeline)
· Add notes (internal/customer)
· Update status
· Email template library (copy)

Phase 3 – Admin Features (Week 3)

· Admin dashboard (team stats)
· User management (create/disable agents, set department)
· Department management
· Case assignment (single/bulk)
· Case type management
· View agent stats (individual)

Phase 4 – Escalation & SLA (Week 4)

· Escalation timer (set + countdown)
· SLA breach warnings
· Overdue escalation view
· Browser notifications

Phase 5 – Reminders & Performance (Week 5)

· Reminder system
· Agent ranking (closures, interactions, weighted)
· Department & case type filters
· Admin email report generator

Phase 6 – Polish & Productize (Week 6)

· Blue theme (Culligan branding)
· Mobile responsiveness
· Export CSV/PDF
· Documentation
· Pitch to management

---

👥 Team Mission for Claude

Claude, you are the full engineering team for this project. Your job:

1. Build with purpose – this tool will boost call centre performance. Every feature must serve that goal.
2. Point out the positive – always highlight what's working well. When giving feedback on agents, frame it constructively.
3. Call out the negative – but with solutions. If something is underperforming, suggest improvements.
4. Think like a manager – what would a team leader want to see? What would make their job easier?
5. Keep it simple – avoid over-engineering. Use the existing stack (Supabase, Vercel, vanilla JS) unless there's a compelling reason to change.

When comparing stats

· Always show both absolute numbers and trends (e.g., "This is a 15% improvement from last week").
· Use colour coding: green for positive trends, red for negative, orange for neutral.
· Celebrate improvements, even small ones.

---

📌 Important Notes

· No Google login – email/password only
· Default admin – thacollin2@gmail.com (password managed in Supabase Auth, not stored in this repo)
· Theme – blue (Culligan water branding)
· Departments – Sales, Customer Service, Tech, Retention, Onboarding (admin configurable)
· Case types – Water Order, Service Request, Swap, Account Updates (admin configurable)
· Escalation timers – 1h, 3h, 8h, 24h, 48h, or custom
· Ranking – based on cases closed, cases interacted, weighted score
· Email templates – admins create; agents copy to use

---

✅ First Steps for Claude

1. Set up Supabase project and create all tables (schema above).
2. Enable auth (email/password) and set RLS policies.
3. Create default admin user.
4. Build admin user creation panel.
5. Begin Phase 1 development.

---

🔄 v2 Update – Build Status & Schema Changes (2026-07-10)

Phase 1 is live. Supabase project `CulliganConnect` (`gitiijehmmovfopgzmtl`, eu-west-1) is
created with schema + RLS + seed data applied (`supabase/migrations/`), and the default admin
(`thacollin2@gmail.com`) exists in Supabase Auth with a `profiles` row (`role = 'admin'`). The
password was shared once out of band and is not stored anywhere in this repo or its history.

The schema above was the v1 plan. The actual applied schema (see `supabase/migrations/`) deviates
in a few places, informed by the real `Culligan_Escalation_Tracker.xlsx` the team was using:

· `departments`, `case_types`, `escalation_reasons` are now real lookup **tables** (not free-text
  columns on `profiles`/`cases`), so admins can add/edit/deactivate them from the Setup screen.
  `profiles.department_id` and `cases.department_id` / `cases.case_type_id` /
  `cases.escalation_reason_id` are FKs into them.
· New `service_centres` table — the 16 real UK depots (code, town, regional manager, depot email,
  CC contacts), seeded from the spreadsheet's Setup tab. A case escalates *to a depot*
  (`cases.service_centre_id`), which is a different concept from the assigned agent's department.
· New `escalation_templates` table — one row per escalation reason, holding both a depot-facing
  and a customer-facing subject/body with `{ACCOUNT} {TASK} {WORKORDER} {SLADATE} {QTY} {SERVICE}
  {NAME} {CUSTOMER} {UPDATE}` tokens, seeded with the 4 real templates from the spreadsheet
  (Over SLA Water Delivery, Run Out of Water, Delayed Service, Delivery Not Received). This is
  distinct from `email_templates`, which is for admin performance-report emails.
· `cases.times_escalated` and `cases.callback_arranged` added, mirroring the spreadsheet's
  "search before you escalate" and "Callback / Reachback Arranged" fields.
· New `case_mentions` table — @mentions/tagging a colleague on a case note for input, with an
  unread flag.
· New `agent_mood_log` table — daily self-reported mood (`great/good/okay/stressed/overwhelmed`
  + optional note), agent-private by default, admins can read (not write) for a team sentiment
  view. Ties into the "call out the positive" mission — not meant to be punitive.
· New `audit_log` table (generic actor/action/entity log — admin-only read), separate from the
  more specific `escalation_audit`.
· RLS policies use a `public.is_admin()` SECURITY DEFINER helper instead of inline subqueries on
  `profiles` in `profiles`' own policies, to avoid Postgres RLS self-referencing recursion.
· Team leaderboards default to **admin-only** visibility (deliberate deviation from "gamify with a
  public leaderboard") — a public ranking of ~30 agents risks sandbagging/resentment; an opt-in
  "share with team" toggle can be added later if wanted.

Repo scaffold in place: `index.html` (login), `admin/index.html` (dashboard shell + live stats),
`admin/users.html` (agent list + create-agent flow), `admin/settings.html` (departments/case
types/service centres/escalation reasons), `css/styles.css` (blue theme), `js/supabaseClient.js` +
`js/auth.js` (shared client/auth-guard), `api/admin/create-user.js` (Vercel serverless function
that uses the service-role key server-side to create agent accounts — the key is never shipped to
the browser).

Not yet built: agent-facing dashboard/case list/case detail, escalation timer UI, reminders,
mood check-in UI, @mention UI, ranking/reports, CSV/PDF export. These are Phases 2-5 from the
roadmap above, now scoped against the real schema instead of the free-text v1 one.

Deployed to Vercel: https://culliganconnect.vercel.app (production).

---

🤖 v3 Update – Backend Automation (2026-07-11)

Added `supabase/migrations/20260711090000_backend_automation.sql` and a follow-up hardening
migration, so the database — not the frontend — is the source of truth for these invariants:

· `set_updated_at()` trigger on `profiles`, `cases`, `email_templates`, `escalation_templates` —
  `updated_at` is never stale because a client forgot to set it.
· `generate_case_number()` — `cases.case_number` is auto-assigned on insert from
  `case_number_seq`, zero-padded to 8 digits (matches the spreadsheet's `00248484` format).
  Never set `case_number` from the client.
· `handle_case_status_change()` — on any `cases.status` change: writes `case_status_history`,
  and specifically on entering `'escalated'`: stamps `escalated_at`/`escalated_by`, increments
  `times_escalated`, computes `escalation_expires_at` from `escalation_timer_hours`, and inserts
  an `escalation_audit` row. On leaving `'escalated'`, closes out the open `escalation_audit` row
  and flags `was_overdue`. On entering/leaving `closed`/`resolved`, sets/clears `closed_at`.
  Do not replicate this logic in the frontend — just update `cases.status` (and
  `escalation_timer_hours` when escalating) and let the trigger do the rest.
· `sync_case_department()` — `cases.department_id` always mirrors the assigned agent's
  `profiles.department_id`; it is derived, not independently settable.
· `sync_case_last_note()` — `cases.notes` (the list-view summary) is set from the newest
  `case_notes.note` (truncated to 280 chars) automatically.
· New `notifications` table (`user_id, type, title, body, data jsonb, is_read`) — generic
  per-user notification inbox, RLS: users read/mark-read their own, admins all. This is what the
  frontend's notification bell/unread badge should query.
· New `org_settings` singleton table (`id boolean primary key check (id)`, one row) holds
  `eod_stats_enabled`, `eod_stats_time`, `eod_stats_timezone` (default `18:00` `Europe/London`),
  `eod_stats_last_run_date`. Readable by any authenticated user, writable by admins only.
  `admin/settings.html` has a form to edit it.
· `send_eod_stats(for_date date)` computes **collective/team-wide** numbers for that date
  (cases closed, created, interacted-with, escalated, SLA breaches, top performer) and inserts
  one `notifications` row per active profile (agents + admins) — not per-agent stats, by design.
· `maybe_send_eod_stats()` runs every minute via `pg_cron` (job `eod-stats-check`, schedule
  `* * * * *`), compares current time in `eod_stats_timezone` against `eod_stats_time`, and fires
  `send_eod_stats()` at most once per calendar day (`eod_stats_last_run_date` guards against
  double-sends). This is how "admin sets a time" turns into "fires once daily" without needing a
  literal cron-expression edit per change — the cron job is fixed at 1-minute granularity and the
  actual send time is data-driven from `org_settings`.
· Security hardening: `handle_case_status_change`, `sync_case_department`, `sync_case_last_note`,
  `maybe_send_eod_stats`, `send_eod_stats` all had `EXECUTE` revoked from `anon`/`authenticated` —
  they're trigger functions / cron-only internals, not meant to be called directly via PostgREST
  RPC (an agent could otherwise call `send_eod_stats` themselves and spam every user). Triggers
  still fire fine without that grant. `set_updated_at`/`generate_case_number` got `search_path`
  pinned per the Supabase linter. `is_admin()` is intentionally still public-callable — it only
  reflects the caller's own session and leaks nothing.
· All of the above was smoke-tested end-to-end against the live Supabase project (insert →
  escalate → note → close → verify history/audit rows → `send_eod_stats` → verify notification →
  cleanup) before being considered done, not just applied and assumed correct.

---

👷 v4 Update – Agent Frontend (2026-07-11)

Built the agent-facing screens: `agent/index.html` (My Day — notifications, today's personal
stats, mood check-in, priority case list sorted by escalation risk), `agent/cases.html`
(searchable/filterable case list + "New case" form with the spreadsheet's "check before you
escalate" account-history hint), `agent/case.html` (case detail: status/escalation controls,
escalation email template copy-to-clipboard with `{TOKEN}` substitution, notes with @mention
tagging, reminders, status history). Shared logic lives in `js/caseHelpers.js` (status badges,
escalation countdown colour bands, template token filling, clipboard copy).

Building this surfaced two real RLS gaps in the v2/v3 schema that would have silently broken
the agent UI, both fixed in `20260711100500_fix_agent_frontend_rls_gaps.sql`:
· `cases` had no INSERT policy for agents — only admins could create cases. Added
  `agents_create_own_cases` (agents may insert cases where `assigned_to = auth.uid()`).
· `profiles` only allowed reading your own row — colleague names in note attribution, case
  history, and the @mention tag-picker would all render blank. Added
  `authenticated_read_profiles` (any signed-in user may read all profiles) — acceptable for a
  ~30-person internal team where the source spreadsheet was already fully shared.

Also added `20260711100000_notify_case_mentions.sql`: a trigger (`notify_case_mention`) that
fires a `notifications` row when someone is tagged via `case_mentions` — the table existed
before this but nothing was creating the notification.

Unlike the DDL-only migrations, these RLS/trigger fixes were verified against **real RLS
enforcement**, not just applied: created a throwaway `agent`-role test user, ran
`set local role authenticated` + `set_config('request.jwt.claims', ...)` to simulate its actual
PostgREST session (the Supabase MCP connection is otherwise a superuser that bypasses RLS
entirely, so testing via that connection directly would prove nothing), exercised case
create/read, note insert, reminder insert, and mention→notification end-to-end, then deleted the
test user and its rows.

Deployment note: the `culliganconnect` Vercel project was created via direct file upload (not
Git-connected), so `git push` alone does not deploy it — someone needs to click "Connect Git
Repository" on the Vercel project and point it at this repo/branch for pushes to auto-deploy.
(Resolved 2026-07-10: Git is now connected; pushes to `main` deploy to production automatically.)

---

🔧 v5 Update – Auth bootstrap bug, agent creation moved to an Edge Function, RLS perf (2026-07-11)

**Root cause of "incorrect email or password" that no password reset fixed:** bootstrapping the
admin account with a raw `INSERT INTO auth.users` left `confirmation_token` and sibling token
columns (`recovery_token`, `email_change_token_new`, `email_change`,
`email_change_token_current`, `phone_change`, `phone_change_token`, `reauthentication_token`) as
`NULL` instead of `''`. GoTrue's Go code cannot scan `NULL` into those fields and crashes with a
500 *before it ever checks the password* — the frontend shows a generic "Incorrect email or
password" for any failure, which is why no amount of password-resetting fixed it. Confirmed via
`get_logs(service: 'auth')`, which showed `error finding user: sql: Scan error on column index
3, name "confirmation_token": converting NULL to string is unsupported` on every attempt.
**If you ever need to bootstrap another user via raw SQL instead of `auth.admin.createUser()`,
explicitly set all the `character varying` columns with `column_default IS NULL` to `''`,** not
just `encrypted_password`/`email`/etc. Users created through the `create-agent` Edge Function
(see below) don't have this problem — they go through Supabase's own Go code, which sets these
correctly.

**Agent creation moved from a Vercel serverless function to a Supabase Edge Function**
(`supabase/functions/create-agent/index.ts`, called from `admin/users.html` via
`supabase.functions.invoke('create-agent', ...)`). The Vercel version
(`api/admin/create-user.js`, now deleted) needed `SUPABASE_SERVICE_ROLE_KEY` set as a Vercel
environment variable, which nobody with access to this session could retrieve or set (by
design — MCP tooling never exposes the service-role key). Supabase Edge Functions get
`SUPABASE_URL`/`SUPABASE_ANON_KEY`/`SUPABASE_SERVICE_ROLE_KEY` injected automatically for
functions in the same project, so this sidesteps the problem entirely — zero Vercel
configuration required. The app is now a pure static site; `package.json` and `api/` were
removed since nothing server-side runs on Vercel anymore. Deploy the function with
`supabase functions deploy create-agent --project-ref gitiijehmmovfopgzmtl`.

**Two real advisor findings, both fixed and re-verified:**
· The v3 "hardening" migration (`revoke execute ... from anon, authenticated`) didn't actually
  close the hole — Postgres grants `EXECUTE` to `PUBLIC` by default on function creation, and
  `anon`/`authenticated` inherit through `PUBLIC` regardless of a role-specific revoke. Checked
  `pg_proc.proacl` directly to confirm; `20260711110000`-adjacent migration
  (`harden_automation_functions_v2` applied live, folded into `20260711110000_performance_hardening.sql`
  going forward) revokes from `PUBLIC` instead, which actually works — verified by re-checking
  `proacl` afterward.
· `auth_rls_initplan` on ~20 policies across every table: calling `auth.uid()`/`auth.role()`
  directly in a policy re-evaluates it per row; wrapping as `(select auth.uid())` makes Postgres
  treat it as a stable initplan evaluated once per query. Rewrote every non-`is_admin()`-only
  policy with `ALTER POLICY ... USING (...) WITH CHECK (...)` (`is_admin()` itself was already
  fine — the wrapping happens inside the function). Also added the 18 missing FK covering
  indexes the advisor flagged.
· Not fixed: `multiple_permissive_policies` (~145 advisor entries) — every table has a separate
  `agents_own_X` + `admins_all_X` policy for the same command, which Postgres evaluates as an OR
  instead of a single combined USING clause. Correct, just not maximally efficient. Left as-is
  deliberately — consolidating ~20 policy pairs is a real refactor with real risk of breaking
  access for a 30-person internal tool with negligible query volume; not worth it unless this
  actually shows up as a bottleneck. `auth_leaked_password_protection` (HaveIBeenPwned checking)
  is also still off — it's an Auth-service config toggle, not reachable via SQL/migrations or
  any tool in this session; someone with dashboard access can flip it under Authentication →
  Policies if wanted.

As with the v4 changes, the RLS policy rewrite was re-verified against **real RLS enforcement**
(throwaway test agent + `set local role authenticated` + simulated JWT claims), not just
applied — every rewritten policy was exercised (profile visibility, case create, note insert,
reminder insert) before and after, then the test user was deleted.

---

📋 v6 Update – Templates, admin case management, reports, audit log (2026-07-11)

Filled in the largest remaining gaps against the original feature list — most notably that
**admins previously had no way to see or assign cases at all** (only a stat-tile count on the
dashboard). New pages, no schema changes needed (all tables already existed):

· `admin/templates.html` — CRUD for `email_templates` (the general canned-response library, e.g.
  "Delivery delayed") and `escalation_templates` (one row per escalation reason: depot + customer
  email, upserted on `escalation_reason_id`). Added `authenticated_read_email_templates` RLS
  policy since agents previously had no read access at all to `email_templates`.
· `agent/templates.html` — agents browse and copy the `email_templates` library (plain
  copy-to-clipboard, no token substitution — that's what the escalation templates on the case
  detail page are for).
· `admin/cases.html` — the missing admin case list: search/filter (status, department,
  at-risk-only), single-row reassign via inline `<select>`, and bulk-select + "Assign selected"
  for multiple cases at once. Rows link into `/agent/case.html?id=...` for full detail — that
  page already works for admins as-is since `admins_all_cases` grants full RLS access regardless
  of `assigned_to`, so it didn't need a separate admin case-detail page.
· `admin/reports.html` — the agent ranking + "Generate performance email report" feature from
  the original spec, combined into one screen since they're the same underlying per-agent stats
  query (closed/interacted/escalated/SLA breaches over a date range, ranked by closed,
  interacted, or a weighted score). Includes CSV export (PDF export is still not implemented).
· `admin/audit-log.html` — simple table over the `audit_log` rows the `create-agent` Edge
  Function has been writing to since v5 (nothing else writes to it yet).

Admin nav grew from 3 items to 7 (Dashboard/Cases/Agents/Templates/Reports/Setup/Audit Log) and
agent nav from 2 to 3 (My Day/Cases/Templates) — kept as plain duplicated `<header>`/`<aside>`
markup per page rather than introducing a shared nav component, matching the rest of the
codebase's style even though the duplication is now spread across 10 files.

Verified against real RLS enforcement again — this time including the **admin path**, which had
only ever been tested via the superuser migration connection (which bypasses RLS and proves
nothing) or via `is_admin()` being asserted true implicitly. Simulated the actual admin account's
session (`set local role authenticated` + its real `auth.uid()`) and exercised: bulk case
reassignment (`admins_all_cases` UPDATE), `email_templates` insert, and confirmed a random
non-admin authenticated session can still read `email_templates` (the new agent-facing policy).
All test rows cleaned up afterward.

Still not built: real-time browser push notifications (in-app notification list exists;
OS-level `Notification` API is not wired up), auto-save on notes (currently save-on-submit
only), keyboard shortcuts, a standalone "Quick Notes" sidebar widget, and PDF export. These are
lower-value/higher-effort relative to what shipped this round.
