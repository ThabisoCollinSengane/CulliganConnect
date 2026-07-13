-- Free-text cohort tag (e.g. "Wave 1", "Wave 2") so admins can group and
-- filter agents by recruiting intake for stats, without needing a lookup
-- table to manage as new waves get added.
alter table profiles add column wave text;
