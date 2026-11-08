# AI Team Blueprint — v1 (8 Nov 2026)

Built to the structure of the owner's "one_shot_setup" prompt: use case → team architecture → agent
design → prompts → workflow → tool stack → QA plan → rules → 7-day launch plan → START HERE FIRST.

The agents are **real, runnable Claude Code subagents** (`.claude/agents/*.md`), not a diagram. Open
Claude Code inside the `english-agency/` folder and they load automatically.

---

## 1. Use case — what the AI team does first

| Option | Value to this business right now | Fit to owner skills | Verdict |
|---|---|---|---|
| Content research & writing | Low — no website yet, no audience | Medium | Later |
| **Lead generation / B2B prospect research (Asia schools + intermediaries)** | **Highest — demand is the bottleneck (HANDOVER risk B)** | High — owner knows campaign-style sales from BPO | **Pick this** |
| Customer support | None — no customers yet | High | Phase 2 |
| Internal operations (rosters, QA, scheduling) | Medium — only matters once a client signs | Very high (call-centre background) | Phase 2 |
| Research assistant (legal/market) | High, but it feeds lead gen | Medium | Included as support role |
| Personal productivity | Low | — | Skip |

**Recommendation:** v1 team = **"Market & Pipeline Desk"**: research which Asian **adult/corporate**
buyers can legally and profitably buy from a South African supplier, find the specific organisations
and HR/L&D buyers, and prepare owner-approved outreach that offers a **paid 90-minute pilot workshop**.
Finding tutors isn't the problem. Finding the first paying client is (HANDOVER v2 §12).

---

## 2. Team architecture (5 roles, 1 human gate)

```
            OWNER (Thabiso) — approves anything that spends, sends, signs, publishes
                 ▲  final package                         │ request
                 │                                        ▼
        ┌─────────────────── CHIEF OF STAFF (main Claude session) ───────────────────┐
        │ writes task brief → routes → assembles → logs DECISIONS.md / HANDOVER.md    │
        └──────┬──────────────────────┬───────────────────────┬──────────────────────┘
               ▼                      ▼                       ▼
     MARKET-RESEARCHER        PROSPECT-BUILDER           OPS-PLANNER
     markets, regs, prices    named orgs + drafts        staffing, shifts, costs,
     → research/RX-*.md       → prospects/*.csv, .md     SA compliance → ops/*.md
               └──────────────────────┼───────────────────────┘
                                      ▼
                               FACT-CHECKER (always last)
                     PASS / FIX / BLOCK each claim → review note
```

| Agent | Owns | Input | Output | Hands to |
|---|---|---|---|---|
| Chief of Staff | Routing, assembly, record-keeping | Owner request | Task brief; final summary | Specialist, then owner |
| market-researcher | Markets, regulation, pricing, competitors | Task brief | `research/RX-*.md` (template) | fact-checker |
| prospect-builder | Named targets + draft outreach (never sent) | Approved market from R2 | `prospects/tracker.csv`, `prospects/drafts/*.md` | fact-checker |
| ops-planner | Team design, shifts, unit economics, compliance briefings | Task brief + research | `ops/*.md` | fact-checker |
| fact-checker | Truth + safety gate | Any draft output | Review note: PASS / FIX / BLOCK | Chief of Staff |

**No overlap rule:** researcher answers *"is this market worth it and what does it pay?"*;
prospect-builder answers *"who exactly, and how do we approach them?"* and may only target markets
the researcher has marked GO; ops-planner answers *"can we deliver it and at what margin?"*;
fact-checker creates nothing new, only verifies.

---

## 3. Agent design (summary — full prompts live in `.claude/agents/`)

### market-researcher
- **Purpose:** decide where to sell and at what price, with evidence.
- **Decision rules:** primary/official sources beat blogs; a single recruiter blog = LOW confidence;
  anything older than 12 months is flagged STALE; a legal blocker overrides any demand signal.
- **Output format:** research template (summary, findings table, sources+date, confidence, open
  questions, recommendation GO / TEST / NO-GO).
- **Success:** every number has a source; recommendation is a clear GO/TEST/NO-GO.

### prospect-builder
- **Purpose:** turn a GO market into 20+ real, named organisations with public contact routes.
- **Decision rules:** adults only; China K-12 leads are declined and logged. Only official/public
  contact info (website contact page, published tender contact, LinkedIn company/role pages). No
  personal emails harvested, no scraping tools. Priority: SMEs and internationally operating
  companies (short decision chains), then language-centre subcontracting, then universities and tenders.
- **Output format:** tracker rows + one tailored draft per top-10 target, status `DRAFT – NOT SENT`.
- **Success:** each row is verifiable by clicking its source link.

### ops-planner
- **Purpose:** prove the agency can deliver the hours at a margin, and stay legal in SA.
- **Decision rules:** use only researched rates; placeholders are marked; staged (2–5 tutors before
  any hub); legal output is a briefing for an accountant/attorney.
- **Success:** a unit-economics sheet the owner can change one number in and see break-even.

### fact-checker
- **Purpose:** stop invented facts and unsafe actions reaching the owner or a prospect.
- **Checks:** every claim has URL + date; the source actually says it; no fake names/contacts; no
  promise the business can't keep; no approval-gated action taken.
- **Success:** zero UNVERIFIED claims presented as fact.

---

## 4. Workflow

1. Owner asks (e.g. "find 20 schools in Vietnam").
2. Chief of Staff fills `templates/task-brief.md` (goal, scope, definition of done, approvals needed).
3. Specialist does the work → writes to its folder, status `DRAFT`.
4. fact-checker reviews → `PASS` (→ step 6), `FIX` (→ back to specialist, max 2 loops), `BLOCK`
   (→ escalate to owner with reason).
5. Feedback loop: fact-checker's FIX list is pasted verbatim into the specialist's next run.
6. Chief of Staff assembles: 5-line summary, what's verified, what's UNVERIFIED, **approvals needed**.
7. Owner approves / rejects → logged in `DECISIONS.md`. Only the owner sends emails or spends money.

---

## 5. Tool stack (v1, solo operator, ~R0–R500/month)

| Tool | Use | Why | Cost |
|---|---|---|---|
| Claude Code (Claude Opus 5.5) | Runs the team; web search; writes files | The agents themselves | Owner's existing Claude plan |
| This git folder (GitHub) | Knowledge base + version history of every research file | One source of truth; nothing gets lost | Free |
| `prospects/tracker.csv` → Google Sheets | CRM v1 (open the CSV in Sheets) | Owner already lives in Salesforce-style pipelines; a sheet is enough for <100 leads | Free |
| Google Drive (connected) | Share research with accountant/attorney | Already connected to this account | Free |
| Task list: GitHub Issues or one `ops/TASKS.md` | Track the 7-day plan | Keep it in the same place as the work | Free |
| Gmail/Outlook — owner only | Sending approved outreach by hand | Keeps the approval gate physical | Free |
| HubSpot free CRM (optional, later) | When leads > ~100 | Connected already; upgrade only when the sheet hurts | Free tier |
| Automation (later) | Weekly scheduled research refresh | Only after v1 proves useful | — |

Deliberately **not** in v1: email-sending automation, scraping tools, paid lead databases.

---

## 6. QA plan

**Checkpoints:** (1) brief approved by Chief of Staff; (2) fact-checker on every output;
(3) owner approval before any outward action.

**Common failure modes and the guard against each**

| Failure | Guard |
|---|---|
| Hallucinated school / contact | fact-checker opens every source link; no source = row deleted |
| Stale law or price | date-checked column; >12 months = STALE flag |
| Confident tone on a weak source | confidence level required per finding |
| Agent "helpfully" emails a prospect | agents have no send tools; drafts marked NOT SENT |
| Scope creep (agent builds website early) | CLAUDE.md: website blocked until name/stack confirmed |
| Overlap/duplicate work | Chief of Staff checks `research/` before briefing |

**Before launch, test:** give each agent one known-answer task (e.g. "Is South Africa on China's
native-English teacher list?" — known answer: commonly listed, UNVERIFIED officially) and confirm
it cites, flags and refuses correctly. Plant one fake fact in a draft; the fact-checker must catch it.

**Is the team helping? (weekly)**
- Hours saved vs. doing research by hand (owner estimate).
- Prospects added / % passing fact-check.
- Outreach sent by owner → replies → calls → **letters of intent** (the only metric that matters
  for Gate 2).

---

## 7. Rules (all agents)
See `CLAUDE.md` → Non-negotiables. Approval required before publishing, sending, deleting, spending
money, registering or signing. Never ask for passwords or secrets in chat.

---

## 8. Seven-day launch plan

| Day | Owner (≈1–2 hrs/day) | AI team |
|---|---|---|
| 1 | Read `research/CHALLENGE-what-breaks.md`. Pick a name from `research/NAMES.md` | — (done today) |
| 2 | Decide launch order (Claude: Vietnam first) and the opening price to test | market-researcher: R4 deep-dive on Vietnam corporate/language-centre buyers |
| 3 | Review prospect list; mark 10 to approach | prospect-builder: 20+ verified adult/corporate targets in the lead market |
| 4 | Edit/approve outreach drafts (offer: paid 90-min pilot workshop) | prospect-builder drafts; fact-checker reviews |
| 5 | **Send** the first 5 personalised LinkedIn/email messages yourself | ops-planner: pilot offer sheet + client contract term sheet (min hours, prepayment, gross-up) |
| 6 | Sign up Cambly/italki (Phase 0) if not done; book accountant + attorney intro | ops-planner: finalise R6 question lists; first China network test plan |
| 7 | Review replies; record price objections | Chief of Staff: weekly report; update HANDOVER/DECISIONS |

---

## START HERE FIRST

1. Open `research/CHALLENGE-what-breaks.md` (pricing vs your 2.0× metric, utilisation, China tax/network).
2. Pick a name in `research/NAMES.md` and write it into `DECISIONS.md`.
3. Open Claude Code in `english-agency/` and type:
   *"Chief of Staff: brief prospect-builder to find 20 Vietnamese companies and language centres
   that buy adult/corporate English training, using R2 and R4. Fact-check before showing me."*
4. Nothing gets sent, spent or registered until you say yes.
