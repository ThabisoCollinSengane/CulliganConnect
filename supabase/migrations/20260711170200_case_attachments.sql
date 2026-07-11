-- Attachments live in a private storage bucket; metadata rows keep the case
-- page listing fast and RLS-governed. Files are served via short-lived signed URLs.
insert into storage.buckets (id, name, public)
values ('case-attachments', 'case-attachments', false)
on conflict (id) do nothing;

create table case_attachments (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references cases(id) on delete cascade,
  uploaded_by uuid not null references profiles(id),
  file_name text not null,
  storage_path text not null unique,
  content_type text,
  size_bytes bigint,
  created_at timestamptz not null default now()
);

create index idx_case_attachments_case on case_attachments(case_id);
create index idx_case_attachments_uploader on case_attachments(uploaded_by);

alter table case_attachments enable row level security;

create policy "team_read_attachments" on case_attachments for select
  using ((select auth.role()) = 'authenticated');
create policy "agents_insert_own_attachments" on case_attachments for insert
  with check (uploaded_by = (select auth.uid()));
create policy "uploader_delete_own_attachments" on case_attachments for delete
  using (uploaded_by = (select auth.uid()));
create policy "admins_all_attachments" on case_attachments for all
  using (is_admin()) with check (is_admin());

create policy "team_read_case_attachment_files" on storage.objects for select
  using (bucket_id = 'case-attachments' and (select auth.role()) = 'authenticated');
create policy "team_upload_case_attachment_files" on storage.objects for insert
  with check (bucket_id = 'case-attachments' and (select auth.role()) = 'authenticated');
create policy "owner_delete_case_attachment_files" on storage.objects for delete
  using (bucket_id = 'case-attachments' and owner = (select auth.uid()));
