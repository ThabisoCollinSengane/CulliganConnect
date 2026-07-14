-- Mentions need to be visible to whoever is reading the note thread, not
-- just the two people directly involved, so a mention chip on a note reads
-- correctly for every agent (case_notes itself is already team-readable via
-- agents_read_all_notes -- this closes the same gap for who was tagged on
-- it). users_read_own_mentions stays for clarity around "my mentions", but
-- is now a strict subset of this.
create policy agents_read_all_case_mentions on case_mentions for select
  using ((select auth.role()) = 'authenticated');
