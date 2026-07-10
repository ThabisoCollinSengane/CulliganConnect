create or replace function public.notify_case_mention()
returns trigger
security definer
set search_path = public
language plpgsql
as $$
declare
  v_case_number text;
  v_by_name text;
begin
  select case_number into v_case_number from cases where id = new.case_id;
  select full_name into v_by_name from profiles where id = new.mentioned_by;

  insert into notifications (user_id, type, title, body, data)
  values (
    new.mentioned_user,
    'mention',
    'You were tagged on case ' || coalesce(v_case_number, ''),
    coalesce(v_by_name, 'A colleague') || ' tagged you for input on case ' || coalesce(v_case_number, ''),
    jsonb_build_object('case_id', new.case_id, 'note_id', new.note_id, 'mentioned_by', new.mentioned_by)
  );
  return new;
end;
$$;

create trigger trg_case_mentions_notify
  after insert on case_mentions
  for each row execute function public.notify_case_mention();

revoke execute on function public.notify_case_mention() from anon, authenticated;
