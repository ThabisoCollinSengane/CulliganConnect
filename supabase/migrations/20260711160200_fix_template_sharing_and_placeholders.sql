-- The sharing trigger forced is_shared=false whenever there was no JWT
-- (auth.uid() is null in superuser/service contexts), which silently turned
-- the seeded team templates into the admin's personal ones — agents saw
-- "No team templates yet". Only force personal when an actual signed-in
-- non-admin makes the change; trusted no-JWT contexts keep what they set.
create or replace function public.enforce_email_template_sharing()
returns trigger
security definer
set search_path = public
language plpgsql
as $$
begin
  if (select auth.uid()) is not null and not public.is_admin() then
    new.is_shared := false;
  end if;
  return new;
end;
$$;

-- Repair the seeds the old trigger de-shared.
update email_templates set is_shared = true
  where name in ('Delivery Delayed','Order Confirmation','Service Visit Scheduled','Account Update Confirmation','Apology & Follow-up')
    and created_by in (select id from profiles where role = 'admin');

-- Give those defaults the fill-in fields the agents' "Use" flow detects:
-- customer-name greeting + account/task reference block.
update email_templates
  set body = replace(body, 'Dear customer,', 'Dear [CUSTOMER NAME],')
  where is_shared = true
    and name in ('Delivery Delayed','Order Confirmation','Service Visit Scheduled','Account Update Confirmation','Apology & Follow-up')
    and body like 'Dear customer,%';

update email_templates
  set body = replace(body, 'Kind regards,',
    'Account number: [ACCOUNT NUMBER]' || chr(10) || 'Task number: [TASK NUMBER]' || chr(10) || chr(10) || 'Kind regards,')
  where is_shared = true
    and name in ('Delivery Delayed','Order Confirmation','Service Visit Scheduled','Account Update Confirmation','Apology & Follow-up')
    and body not like '%[ACCOUNT NUMBER]%';
