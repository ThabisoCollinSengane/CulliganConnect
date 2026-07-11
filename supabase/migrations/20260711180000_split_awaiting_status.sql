-- Split 'awaiting_response' into 'awaiting_internal' (waiting on a depot /
-- another team) and 'awaiting_customer' (waiting on the customer), so stats
-- show where cases actually get stuck. Any legacy rows are treated as
-- waiting-on-customer, the more common call-centre meaning.
update cases set status = 'awaiting_customer' where status = 'awaiting_response';

alter table cases drop constraint cases_status_check;
alter table cases add constraint cases_status_check
  check (status in ('new', 'pending', 'escalated', 'awaiting_internal', 'awaiting_customer', 'resolved', 'closed'));
