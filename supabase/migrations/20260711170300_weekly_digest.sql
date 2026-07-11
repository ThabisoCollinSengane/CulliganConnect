-- Monday-morning week-in-review notification per active agent: closed cases
-- (credited to the closer), calls taken, escalations raised, and rank.
-- Scheduled 07:00 UTC Monday (~08:00 London in summer, 07:00 in winter).
create or replace function public.send_weekly_digest()
returns void
security definer
set search_path = public
language plpgsql
as $$
declare
  r record;
  v_total_closed int;
begin
  select count(*) into v_total_closed
  from cases where status in ('closed','resolved') and closed_at >= now() - interval '7 days';

  for r in
    with stats as (
      select p.id, p.full_name,
        (select count(*) from cases c where c.closed_by = p.id and c.closed_at >= now() - interval '7 days') as closed,
        (select coalesce(sum(cl.calls_taken), 0) from call_logs cl where cl.agent_id = p.id and cl.call_date >= current_date - 7) as calls,
        (select count(*) from cases c where c.escalated_by = p.id and c.escalated_at >= now() - interval '7 days') as escalated
      from profiles p
      where p.role = 'agent' and p.is_active = true
    )
    select s.*, rank() over (order by s.closed desc) as rnk, count(*) over () as total_agents
    from stats s
  loop
    insert into notifications (user_id, type, title, body, data)
    values (
      r.id,
      'weekly_digest',
      '📈 Your week in review',
      format('Last week you closed %s case(s), took %s call(s) and raised %s escalation(s). You ranked #%s of %s agents by cases closed — team total: %s closed. New week, fresh start!',
        r.closed, r.calls, r.escalated, r.rnk, r.total_agents, v_total_closed),
      '{}'::jsonb
    );
  end loop;
end;
$$;

revoke execute on function public.send_weekly_digest() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname = 'weekly-digest';
select cron.schedule('weekly-digest', '0 7 * * 1', $$select public.send_weekly_digest();$$);
