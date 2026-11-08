# Team structure — humans + AI, by phase
**Date:** 2026-11-08 · **Author:** ops-planner (first pass) · **Status:** DRAFT. Pay figures are the owner's (HANDOVER v2 §4); everything else is a proposal

## Org chart at each gate
```
Phase 0–1 (now)          Phase 2 (pilot)                 Phase 4 (hub, 10–20 seats)
───────────────          ───────────────                 ──────────────────────────
Owner/Director (sales)   Owner/Director (sales)          Director (sales + key accounts)
  + AI team                + AI team                       ├─ Operations Manager
  + accountant/attorney    ├─ 3–5 Tutors (employed)        │    ├─ Team Leader/QA (1 per ~10 tutors)
    (on demand)            └─ (strongest tutor = acting    │    │     └─ Tutors
                               TL/QA with stipend at 5+)   │    ├─ Scheduler / Workforce mgmt
                                                           │    └─ IT & facilities (part-time)
                                                           ├─ Recruiter/Trainer
                                                           └─ Finance/admin (outsourced bookkeeper)
```

## Roles (call-centre equivalents)
| Role | BPO equivalent | Owns | KPIs | When |
|---|---|---|---|---|
| Director / Sales | Account director / business development | Pipeline, pricing, contracts, client relationships | Qualified calls/week, LOIs, signed committed hours | Now |
| Tutor | Agent | Lessons per client "campaign" | Attendance, on-time login, lesson QA score, learner satisfaction | After first paid pilot |
| Team Leader / QA | Team leader + QA analyst | Lesson observation, scoring, coaching, cover allocation | Team QA average, absenteeism, client escalations | 5+ tutors |
| Scheduler (WFM) | Workforce management | Rosters against committed client hours, cover tutors | Utilisation, schedule adherence, unfilled slots | ~10 tutors (director/TL until then) |
| Recruiter / Trainer | Recruitment + training | Screening (English test, mock lesson, police clearance), onboarding curriculum | Time-to-hire, 90-day retention, training pass rate | Owner until hub |
| IT & facilities | Site IT | Dual fibre, UPS/inverter, headsets, platform access (Tencent Meeting/VooV for China) | Lesson minutes lost to tech/power | Hub |
| Accountant / Attorney | — | Payroll, VAT, contracts, POPIA | — | On demand from now |

## AI team mapping (who supports whom)
| Human role | AI agent supporting it |
|---|---|
| Director / Sales | prospect-builder (targets + drafts), market-researcher (markets, prices) |
| Ops / TL / Scheduler | ops-planner (rosters, unit economics, QA rubric) |
| Everyone | fact-checker (nothing unverified reaches a client) · Chief of Staff (routing, records) |

## Shift model (draft – depends on what clients actually book; see CHALLENGE §2)
| Shift (SAST) | Covers | Notes |
|---|---|---|
| **Day shift 09:00–17:00** | China evening 18:00–21:00 (=12:00–15:00 SAST); Vietnam/Thailand evening (=13:00–16:00 SAST) | Default shift. Peak in the middle; mornings need daytime/async work (lesson prep, QA, feedback reports) |
| Early shift 04:00–12:00 (only if sold) | China/Vietnam in-office daytime training | Only with signed committed hours; attorney check on night/early-work rules + transport/safety |

## Hiring rule
Hire tutors **against signed committed hours**, in batches (3–5 → 10 → 20), never against forecasts.
