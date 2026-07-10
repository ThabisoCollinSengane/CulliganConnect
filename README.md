# CulliganConnect

Internal case management and performance tracking tool for the Culligan water call centre.
See `.claude/CLAUDE.md` for the full product spec.

## Stack

Vanilla HTML/CSS/JS (no build step, no framework) + Supabase (Postgres, Auth, RLS, Edge
Functions). Deployed on Vercel as a **static site** — there's no server component to configure.

## Project structure

```
index.html               Login page (single login for both agents and admins)
admin/                     Admin-only pages (dashboard, agents, setup)
agent/                     Agent-facing pages (My Day, case list, case detail)
css/styles.css              Culligan blue theme
js/                          Shared client-side modules (Supabase client, auth guard, helpers)
supabase/migrations/        SQL migrations (schema, RLS policies, triggers, seed data)
supabase/functions/         Supabase Edge Functions (privileged operations)
```

## Supabase project

- Project: `CulliganConnect` (`gitiijehmmovfopgzmtl`, eu-west-1)
- Schema, RLS policies, triggers and seed data (departments, case types, service centres,
  escalation reasons/templates) are defined in `supabase/migrations/`. Run them with the
  Supabase CLI (`supabase db push`) against a fresh project, or apply them via the Supabase
  MCP/dashboard.
- The anon/publishable key is safe to ship client-side (`js/supabaseClient.js`) — every table
  has RLS enabled, so access is enforced server-side regardless of what key the browser holds.

## Privileged operations (Edge Functions)

`supabase/functions/create-agent` creates an agent's Auth account + profile row. It's called
from `admin/users.html` via `supabase.functions.invoke('create-agent', ...)`. This runs as a
Supabase Edge Function rather than a Vercel serverless function specifically so the
service-role key never needs to be copied into Vercel's environment variables — Supabase
injects it automatically for functions in the same project. Deploy changes with:

```
supabase functions deploy create-agent --project-ref gitiijehmmovfopgzmtl
```

## Login

Everyone signs in on the same page (`index.html`). After authenticating, the page reads the
account's `profiles.role` and redirects: `admin` → `/admin/index.html`, `agent` →
`/agent/index.html`.

## Default admin

The first admin account (`thacollin2@gmail.com`) was created directly in Supabase Auth.
Its password is not stored anywhere in this repo — it was shared once, out of band, and should
be rotated by the admin on first login.

## Status

Phase 1 (database + auth), the admin panel, and the agent-facing dashboard/case list/case
detail are in place. Ranking/reports and CSV/PDF export are next.
