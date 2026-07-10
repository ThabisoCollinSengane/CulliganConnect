# CulliganConnect

Internal case management and performance tracking tool for the Culligan water call centre.
See `.claude/CLAUDE.md` for the full product spec.

## Stack

Vanilla HTML/CSS/JS + Vercel serverless functions (`/api`) + Supabase (Postgres, Auth, RLS).
No build step for the frontend — pages import `@supabase/supabase-js` straight from a CDN.

## Project structure

```
index.html            Login / landing page
admin/                 Admin-only pages (dashboard, agents, setup)
css/styles.css          Culligan blue theme
js/                     Shared client-side modules (Supabase client, auth guard)
api/admin/create-user.js  Serverless endpoint for creating agent accounts (uses the service-role key)
supabase/migrations/    SQL migrations (schema, RLS policies, seed data)
```

## Supabase project

- Project: `CulliganConnect` (`gitiijehmmovfopgzmtl`, eu-west-1)
- Schema, RLS policies and seed data (departments, case types, service centres, escalation
  reasons/templates) are defined in `supabase/migrations/`. Run them with the Supabase CLI
  (`supabase db push`) against a fresh project, or apply them via the Supabase MCP/dashboard.
- The anon/publishable key is safe to ship client-side (`js/supabaseClient.js`) — every table
  has RLS enabled, so access is enforced server-side regardless of what key the browser holds.

## Environment variables (Vercel)

Set these in the Vercel project settings — see `.env.example`. `SUPABASE_SERVICE_ROLE_KEY` must
never be committed; it bypasses RLS and is only used inside `/api` serverless functions.

## Default admin

The first admin account (`thacollin2@gmail.com`) was created directly in Supabase Auth.
Its password is not stored anywhere in this repo — it was shared once, out of band, and should
be rotated by the admin on first login.

## Status

Phase 1 (database + auth) and the admin shell (dashboard, agent management, departments/case
types/service centres/escalation reasons setup) are in place. Case list/detail, escalation
timers, reminders, and the agent-facing dashboard are next.
