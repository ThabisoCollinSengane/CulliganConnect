-- Callback workflow: quick notes can carry structured customer details, and a
-- reminder can point at a saved note so the agent can copy the details when
-- the reminder comes due.
alter table quick_notes
  add column customer_name text,
  add column business_name text,
  add column phone text,
  add column email text,
  add column account_number text,
  add column task_number text;

alter table reminders add column quick_note_id uuid references quick_notes(id) on delete set null;
create index idx_reminders_quick_note on reminders(quick_note_id);
