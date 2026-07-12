-- Store the Salesforce case number on imported cases so agents can cross-reference.
alter table cases add column if not exists external_case_number text;
create index if not exists idx_cases_external_number on cases(external_case_number);

-- Departments that mirror the Salesforce case types, so the importer can route
-- each case to the matching department automatically.
insert into departments (name, description, is_active)
select v.name, v.descr, true
from (values
  ('Water Ordering', 'Water ordering cases from Salesforce'),
  ('Service Request', 'Service request cases from Salesforce'),
  ('Account Update', 'Account update cases from Salesforce'),
  ('Tech Support', 'Technical support cases from Salesforce')
) as v(name, descr)
where not exists (select 1 from departments d where lower(d.name) = lower(v.name));
