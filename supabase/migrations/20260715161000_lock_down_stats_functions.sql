-- `revoke ... from public` leaves Supabase's default per-role grants intact, so
-- the stats functions were still exposed as REST RPC to anon/authenticated
-- (flagged by the security advisor). compute_daily_stats is only ever called by
-- the nightly cron job (which runs as a privileged role), and
-- set_case_first_touch_from_note only runs as a trigger — neither should be
-- callable by clients. Revoking EXECUTE from anon/authenticated does not affect
-- trigger firing or cron execution.
revoke execute on function public.compute_daily_stats(date) from anon, authenticated;
revoke execute on function public.set_case_first_touch_from_note() from public, anon, authenticated;
