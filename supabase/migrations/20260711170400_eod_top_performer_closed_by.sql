-- EOD "top performer" credits whoever closed the cases (closed_by), matching
-- the daily meter, leaderboards and reports after the shared-queue change.
-- (Identical to the original send_eod_stats otherwise.)
create or replace function public.send_eod_stats(for_date date)
returns void
security definer
set search_path = public
language plpgsql
as $$
declare
  v_cases_closed int;
  v_cases_created int;
  v_cases_interacted int;
  v_escalated_count int;
  v_sla_breach_count int;
  v_top_performer text;
  v_top_closed int;
  v_title text;
  v_body text;
begin
  select count(*) into v_cases_closed from cases where closed_at::date = for_date;
  select count(*) into v_cases_created from cases where created_at::date = for_date;
  select count(distinct case_id) into v_cases_interacted from case_notes where created_at::date = for_date;
  select count(*) into v_escalated_count from cases where escalated_at::date = for_date;
  select count(*) into v_sla_breach_count from cases where sla_date < for_date and closed_at is null;

  select p.full_name, cnt into v_top_performer, v_top_closed
  from (
    select closed_by, count(*) as cnt
    from cases
    where closed_at::date = for_date and closed_by is not null
    group by closed_by
    order by count(*) desc
    limit 1
  ) t
  join profiles p on p.id = t.closed_by;

  v_title := 'End of day stats – ' || to_char(for_date, 'DD Mon YYYY');
  v_body := format(
    'Team results for today: %s cases closed, %s new cases, %s cases interacted with, %s escalations, %s SLA breaches.%s',
    v_cases_closed, v_cases_created, v_cases_interacted, v_escalated_count, v_sla_breach_count,
    case when v_top_performer is not null
      then format(' Top performer: %s (%s closed).', v_top_performer, v_top_closed)
      else ''
    end
  );

  insert into notifications (user_id, type, title, body, data)
  select
    p.id,
    'eod_stats',
    v_title,
    v_body,
    jsonb_build_object(
      'date', for_date,
      'cases_closed', v_cases_closed,
      'cases_created', v_cases_created,
      'cases_interacted', v_cases_interacted,
      'escalated_count', v_escalated_count,
      'sla_breach_count', v_sla_breach_count,
      'top_performer', v_top_performer,
      'top_performer_closed', v_top_closed
    )
  from profiles p
  where p.is_active = true;
end;
$$;

revoke execute on function public.send_eod_stats(date) from public;
