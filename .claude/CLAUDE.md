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
