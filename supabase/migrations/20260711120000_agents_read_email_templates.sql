create policy "authenticated_read_email_templates" on email_templates for select
  using ((select auth.role()) = 'authenticated');
