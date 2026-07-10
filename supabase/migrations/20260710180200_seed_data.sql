-- Culligan Case Tracker: seed data (from the real Culligan_Escalation_Tracker.xlsx)

-- Departments
insert into departments (name, description) values
  ('Sales', 'New business, quotes, upsells'),
  ('Customer Service', 'General inquiries, complaints, account queries'),
  ('Tech Department', 'Dispensers, repairs, installations'),
  ('Retention', 'Cancellations, retention offers'),
  ('Onboarding', 'New customer setups, welcome calls');

-- Case types
insert into case_types (name) values
  ('Water Order'),
  ('Service Request'),
  ('Swap'),
  ('Account Updates');

-- Escalation reasons (status-dropdown reasons + the 4 that have ready-made templates)
insert into escalation_reasons (name) values
  ('Over SLA – Water Delivery'),
  ('Over SLA – Dispenser Install'),
  ('Over SLA – Dispenser Service/Repair'),
  ('Missing / Incomplete Order'),
  ('Incorrect Order'),
  ('Run Out of Water (Expedite)'),
  ('Delayed Service / Engineer Attendance'),
  ('Delivery Not Received (marked delivered)'),
  ('Other');

-- Service centres (UK depot directory)
insert into service_centres (code, name, town, regional_manager, depot_email, cc_contacts) values
  ('UK112', 'UK112- Peterborough', 'Peterborough', 'Steve Lowcock', 'everyonepeterboroughdistribution@culligan.co.uk', 'maris.vite@culligan.co.uk'),
  ('UK113', 'UK113- Ipswich', 'Ipswich', 'Steve Lowcock', 'EveryoneIpswich@culligan.co.uk', 'marcus.burrell@culligan.co.uk; ian.baguley@culligan.co.uk'),
  ('UK121', 'UK121- Hemel', 'Hemel', 'Chris Stoner', 'Hemel.deliveries.cuk@culligan.co.uk', 'sharon.murphy@culligan.co.uk; sam.griffiths@culligan.co.uk'),
  ('UK131', 'UK131- Redhill', 'Redhill', 'Chris Stoner', 'EveryoneRedhill@culligan.co.uk', 'michael.horwood@culligan.co.uk; rob.conlon@culligan.co.uk'),
  ('UK132', 'UK132- Marden', 'Marden', 'Chris Stoner', 'everyone.marden@culligan.co.uk', 'lee.elam@culligan.co.uk; steve.maryon@culligan.co.uk'),
  ('UK141', 'UK141- Ringwood', 'Ringwood', 'Chris Stoner', 'EveryoneRingwood@culligan.co.uk', 'michele.mckiernan@culligan.co.uk; Law.jess@culligan.co.uk'),
  ('UK142', 'UK142- Bristol', 'Bristol', 'Chris Stoner', 'EveryoneBristol@culligan.co.uk', 'laura.dyer@culligan.co.uk; joe.whitman@culligan.co.uk'),
  ('UK143', 'UK143- Plymouth', 'Plymouth', 'Chris Stoner', 'EveryonePlymouth@culligan.co.uk', 'scott.mathison@culligan.co.uk'),
  ('UK154', 'UK154- Wolverhampton', 'Wolverhampton', 'Steve Lowcock', 'everyonewolvesdistribution@culligan.co.uk', 'kevin.millinchip@culligan.co.uk'),
  ('UK161', 'UK161- Haydock', 'Haydock', 'Steve Lowcock', 'EveryoneWarrington@culligan.co.uk', 'daniel.jepson@culligan.co.uk; mark.simon@culligan.co.uk'),
  ('UK162', 'UK162- Dewsbury', 'Dewsbury', 'Steve Lowcock', 'everyoneDewsbury@culligan.co.uk', 'Tracy.mulholland@culligan.co.uk; Sarah.rourke@culligan.co.uk'),
  ('UK163', 'UK163- Malton', 'Malton', 'Steve Lowcock', 'malton@culligan.co.uk', 'Terri.hartas@culligan.co.uk; Andrew.stratford@culligan.co.uk'),
  ('UK171', 'UK171- Gateshead', 'Gateshead', 'Steve Lowcock', 'everyonegateshead@culligan.co.uk', 'amanda.davidson@culligan.co.uk; paul.baily@culligan.co.uk'),
  ('UK172', 'UK172- East Kilbride', 'East Kilbride', 'Steve Lowcock', 'everyonescotland@culligan.co.uk', 'zander.kerr@waterlogic.co.uk; david.hay@culligan.co.uk'),
  ('UK181', 'UK181- Narbeth', 'Narbeth', 'Chris Stoner', 'EveryoneNarbeth@culligan.co.uk', 'lowri.gear@culligan.co.uk; rhys.davis@culligan.co.uk'),
  ('UK182', 'UK182- Margam', 'Margam', 'Chris Stoner', 'EveryoneMargam@culligan.co.uk', 'lowri.gear@culligan.co.uk; rhys.davis@culligan.co.uk');

-- Escalation templates (depot + customer emails, {TOKENS} substituted at send time)
insert into escalation_templates (escalation_reason_id, depot_subject, depot_body, customer_subject, customer_body)
select id, 'URGENT – Over SLA Water Delivery (Task {TASK} / WO {WORKORDER})', 'Hi Team,

Please could you urgently review the below delivery, as it is now past its SLA due date and the customer has advised that the order has not yet been received.

•  Account Number: {ACCOUNT}
•  Task Number: {TASK}
•  Work Order: {WORKORDER}
•  SLA Due Date: {SLADATE}
•  Order Quantity: {QTY}

The customer is requesting an update on the status of the order and would like confirmation of the earliest possible delivery date.

Could you please:
•  Review the current status of the task
•  Confirm the reason for the delay
•  Advise when delivery can be completed
•  Prioritise the order where possible

Please provide feedback at your earliest convenience so we can update the customer accordingly.

Kind regards,
{NAME}
Culligan Customer Services', 'Update on your water delivery – Account {ACCOUNT}', 'Dear {CUSTOMER},

Thank you for your patience. Following your recent contact about your outstanding water delivery, we escalated this to our local service centre and have now received an update:

{UPDATE}

We are sorry for the delay caused and appreciate your understanding. If you have any further questions, please don''t hesitate to contact us.

Kind regards,
{NAME}
Culligan Customer Services'
from escalation_reasons where name = 'Over SLA – Water Delivery';

insert into escalation_templates (escalation_reason_id, depot_subject, depot_body, customer_subject, customer_body)
select id, 'URGENT – Expedite Water Delivery Request (Task {TASK} / WO {WORKORDER})', 'Hi Team,

Please could you assist with urgently expediting the below delivery:

•  Account Number: {ACCOUNT}
•  Task Number: {TASK}
•  Work Order: {WORKORDER}
•  Order Quantity: {QTY}

Although the order remains within SLA, the customer has advised that they have now run out of water on site and require the delivery as soon as possible.

Could you please:
•  Review the task
•  Confirm whether delivery can be brought forward
•  Advise on the earliest available delivery date
•  Prioritise the order where operationally possible

Your assistance would be greatly appreciated as the customer''s requirement has become urgent.

Kind regards,
{NAME}
Culligan Customer Services', 'Update on your urgent water delivery – Account {ACCOUNT}', 'Dear {CUSTOMER},

Thank you for letting us know that you had run out of water. We raised this as urgent with our local service centre and have received the following update:

{UPDATE}

We have done everything we can to prioritise your delivery. Please let us know if there is anything else we can help with in the meantime.

Kind regards,
{NAME}
Culligan Customer Services'
from escalation_reasons where name = 'Run Out of Water (Expedite)';

insert into escalation_templates (escalation_reason_id, depot_subject, depot_body, customer_subject, customer_body)
select id, 'URGENT – Service Attendance Update Required (Task {TASK} / WO {WORKORDER})', 'Hi Team,

Please could you review the below service request, as the customer is chasing an update regarding engineer attendance.

•  Account Number: {ACCOUNT}
•  Task Number: {TASK}
•  Work Order: {WORKORDER}
•  Service Type: {SERVICE}
•  SLA Due Date: {SLADATE}

The customer has advised that they have not received any recent communication regarding the visit and would like an update on when an engineer is expected to attend site.

Could you please:
•  Review the current status of the service task
•  Confirm whether the job has been scheduled
•  Advise on the expected attendance date
•  Escalate or prioritise where necessary

Please provide feedback as soon as possible so we can keep the customer informed.

Kind regards,
{NAME}
Culligan Customer Services', 'Update on your service visit – Account {ACCOUNT}', 'Dear {CUSTOMER},

Thank you for your patience regarding your outstanding service visit. We contacted our local service centre for an update and they have advised the following:

{UPDATE}

We are sorry for any inconvenience caused by the delay. If the proposed arrangements do not suit you, please get in touch and we will do our best to help.

Kind regards,
{NAME}
Culligan Customer Services'
from escalation_reasons where name = 'Delayed Service / Engineer Attendance';

insert into escalation_templates (escalation_reason_id, depot_subject, depot_body, customer_subject, customer_body)
select id, 'URGENT – Delivery Investigation Required (Task {TASK} / WO {WORKORDER})', 'Hi Team,

Please could you investigate the below order, as the customer has advised that they have not received the delivery despite it being marked as completed.

•  Account Number: {ACCOUNT}
•  Task Number: {TASK}
•  Work Order: {WORKORDER}

Could you please review:
•  Proof of Delivery
•  Delivery location
•  Signature details
•  Completion notes

Please advise whether a redelivery should be arranged or if a replacement order needs to be raised.

Many thanks,
{NAME}
Culligan Customer Services', 'Update on your delivery query – Account {ACCOUNT}', 'Dear {CUSTOMER},

Thank you for letting us know that your delivery had been marked as completed but not received. We asked our local service centre to investigate and they have come back to us with the following:

{UPDATE}

We are sorry for the inconvenience and appreciate your patience while we looked into this. Please let us know if there is anything further we can do.

Kind regards,
{NAME}
Culligan Customer Services'
from escalation_reasons where name = 'Delivery Not Received (marked delivered)';
