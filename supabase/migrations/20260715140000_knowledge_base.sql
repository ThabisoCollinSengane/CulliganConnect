-- Internal knowledge base: admin-curated articles (markdown), searchable and
-- filterable by agents, with optional file attachments (the original PDF/Word/
-- Excel source) stored in a private bucket and served via signed URLs.

-- ============================================================
-- Articles. Full-text search via a generated tsvector (title weighted highest,
-- then category, then body). Agents read; admins write.
-- ============================================================
create table kb_articles (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null default '',
  category text,
  tags text[] not null default '{}',
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  search_vector tsvector generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(category, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(content, '')), 'C')
  ) stored
);

create index idx_kb_articles_search on kb_articles using gin(search_vector);
create index idx_kb_articles_category on kb_articles(category);
create index idx_kb_articles_tags on kb_articles using gin(tags);

alter table kb_articles enable row level security;

create policy authenticated_read_kb_articles on kb_articles for select
  using ((select auth.role()) = 'authenticated');
create policy admins_write_kb_articles on kb_articles for all
  using (is_admin()) with check (is_admin());

create trigger trg_90_kb_articles_updated_at
  before update on kb_articles
  for each row execute function public.set_updated_at();

-- ============================================================
-- Attachments: original source files kept alongside the article. Metadata row
-- for a fast RLS-governed listing; files live in a private bucket.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('kb-files', 'kb-files', false)
on conflict (id) do nothing;

create table kb_attachments (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references kb_articles(id) on delete cascade,
  uploaded_by uuid references profiles(id) on delete set null,
  file_name text not null,
  storage_path text not null unique,
  content_type text,
  size_bytes bigint,
  created_at timestamptz not null default now()
);

create index idx_kb_attachments_article on kb_attachments(article_id);

alter table kb_attachments enable row level security;

create policy authenticated_read_kb_attachments on kb_attachments for select
  using ((select auth.role()) = 'authenticated');
create policy admins_write_kb_attachments on kb_attachments for all
  using (is_admin()) with check (is_admin());

-- Bucket policies: everyone signed-in can read (download via signed URL);
-- only admins upload/remove, since the KB is admin-curated.
create policy team_read_kb_files on storage.objects for select
  using (bucket_id = 'kb-files' and (select auth.role()) = 'authenticated');
create policy admins_upload_kb_files on storage.objects for insert
  with check (bucket_id = 'kb-files' and is_admin());
create policy admins_delete_kb_files on storage.objects for delete
  using (bucket_id = 'kb-files' and is_admin());
