-- These security-definer functions fan out notifications and must only run from
-- the pg_cron job (postgres/owner context), never be callable by a signed-in
-- client. Earlier "revoke ... from public" left Supabase's explicit anon/
-- authenticated default-privilege grants in place, so they were still callable.
-- Revoke from all three explicitly.
revoke execute on function public.notify_overdue_escalations() from public, anon, authenticated;
revoke execute on function public.notify_prebreach_escalations() from public, anon, authenticated;
revoke execute on function public.send_weekly_digest() from public, anon, authenticated;
