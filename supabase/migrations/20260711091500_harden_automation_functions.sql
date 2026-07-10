-- Pin search_path on the two functions the security linter flagged.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.generate_case_number()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.case_number is null then
    new.case_number := lpad(nextval('public.case_number_seq')::text, 8, '0');
  end if;
  return new;
end;
$$;

-- These are trigger functions / internal cron jobs, not intended to be called
-- directly via PostgREST RPC. Triggers still fire fine without EXECUTE granted
-- to anon/authenticated (trigger invocation isn't subject to this grant).
revoke execute on function public.handle_case_status_change() from anon, authenticated;
revoke execute on function public.sync_case_department() from anon, authenticated;
revoke execute on function public.sync_case_last_note() from anon, authenticated;
revoke execute on function public.maybe_send_eod_stats() from anon, authenticated;
revoke execute on function public.send_eod_stats(date) from anon, authenticated;
