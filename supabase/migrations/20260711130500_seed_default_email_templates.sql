-- Example default (shared) email templates, seeded under whichever admin
-- profile exists first. Skips silently if no admin exists yet.
do $$
declare
  admin_id uuid;
begin
  select id into admin_id from profiles where role = 'admin' order by created_at limit 1;
  if admin_id is null then
    return;
  end if;

  insert into email_templates (name, subject, body, category, created_by, is_shared) values
  ('Delivery Delayed', 'Update on your water delivery', 'Dear customer,

Thank you for your patience. We wanted to let you know that your delivery has been delayed, and the new estimated arrival is [DATE/TIME].

We apologise for any inconvenience this may cause and are working to get your order to you as soon as possible.

Kind regards,
[YOUR NAME]
Culligan Customer Services', 'Delivery', admin_id, true),

  ('Order Confirmation', 'Your order has been confirmed', 'Dear customer,

Thank you for your order. This is to confirm we have received it and it is now being processed.

Order reference: [ORDER NUMBER]
Expected delivery: [DATE]

If you have any questions in the meantime, feel free to get in touch.

Kind regards,
[YOUR NAME]
Culligan Customer Services', 'Orders', admin_id, true),

  ('Service Visit Scheduled', 'Your service visit is confirmed', 'Dear customer,

Your service/repair visit has been scheduled for [DATE] between [TIME WINDOW]. An engineer will be in touch shortly before arrival.

Please ensure someone is available at the property, or let us know if you need to reschedule.

Kind regards,
[YOUR NAME]
Culligan Customer Services', 'Service', admin_id, true),

  ('Account Update Confirmation', 'Your account details have been updated', 'Dear customer,

This confirms that the changes you requested to your account have now been made.

If anything looks incorrect or you did not request this change, please contact us immediately.

Kind regards,
[YOUR NAME]
Culligan Customer Services', 'Account', admin_id, true),

  ('Apology & Follow-up', 'Following up on your recent enquiry', 'Dear customer,

I''m sorry for the inconvenience caused. I wanted to personally follow up and let you know [UPDATE/RESOLUTION].

Please don''t hesitate to reach out if there''s anything else we can help with.

Kind regards,
[YOUR NAME]
Culligan Customer Services', 'General', admin_id, true);
end $$;
