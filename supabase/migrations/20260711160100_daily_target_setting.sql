-- Org-wide daily target every agent's dashboard meter fills toward.
-- "Closed interactions" = cases closed today + calls taken today.
alter table org_settings add column daily_target int not null default 30 check (daily_target > 0);
