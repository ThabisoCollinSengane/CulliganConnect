# What is most likely to break — and what evidence would settle it
**Date:** 2026-11-08 · **Author:** Claude (Chief of Staff, with market-researcher input) · **Status:** For owner review
**Basis:** HANDOVER v2. All figures are recomputed from the owner's own inputs unless a source is given.
FX is assumed at **R18 = US$1 (UNVERIFIED, check the live rate)**.

I agree with your headline: demand and sales are the bottleneck. But the plan has **two maths problems
and three China problems** that can sink it even if sales go well. They're ranked below by how likely
they are to kill the business.

---

## 1. The pricing breaks the plan's own governing metric (certain, from your own numbers)
HANDOVER §5 says client rate ÷ cost per billable hour must stay above **2.0–2.5×**. At the recommended
opening price it doesn't:

| Client rate | ZAR (R18) | ÷ R140 cost | ÷ R145 cost |
|---|---|---|---|
| US$12 | R216 | **1.54×** | 1.49× |
| US$14 | R252 | **1.80×** | 1.74× |
| US$16 | R288 | 2.06× | 1.99× |
| US$20 | R360 | 2.57× | 2.48× |

So either the metric is wrong or the price is. **US$12–14 only covers fixed costs at high utilisation,
and the 2.0× floor implies ~US$16 opening and ~US$20 for 2.5×.**
Break-even check: R60,000 fixed ÷ R74/hr (US$12 margin) = 811 billable hrs ≈ 6.7 tutors at 70%. That's
before any salary for you as director.
**Evidence that settles it:** 10 real price conversations with buyers (R4). If buyers accept US$16+
for a *managed* programme (reporting, cover tutors, QA), the plan works. If they anchor at US$8–12,
the hub model fails and you need a different delivery model, not just a lower price.

## 2. Utilisation will be far below 70% at the start, because adult demand is peaky (very likely)
Your cost per billable hour assumes 70%. Recomputed with your inputs:

**Loaded cost per tutor/month** = R16,000 + R1,333 (13th cheque) + R160 (employer UIF 1%, under the
R17,712 ceiling) + R173 (SDL 1%, applies once payroll passes R500k/yr, i.e. about 3 tutors) + ~R750
(average attendance bonus) + COIDA (UNVERIFIED, small) ≈ **R18,420**. That matches the top of your
range and excludes retention bonuses.
Sources for UIF/SDL figures: https://www.teamed.global/country-hiring-guides/south-africa/cost-breakdown ,
https://yourincomecalculator.com/za/blog/uif-contributions-benefits-complete-guide-sa-workers
(payroll vendors, checked 2026-11-08, MED confidence; confirm on SARS).

| Utilisation of 173 paid hrs | Billable hrs | Cost / billable hr | Margin at US$12 (R216) | Margin at US$14 (R252) |
|---|---|---|---|---|
| 80% | 139 | R133 | R83 (38%) | R119 (47%) |
| 70% | 121 | **R152** | R64 (30%) | R100 (40%) |
| 60% | 104 | R177 | R39 (18%) | R75 (30%) |
| 50% | 87 | R212 | **R4 (2%)** | R40 (16%) |
| 40% | 69 | R266 | **−R50 (loss)** | −R14 (loss) |

Note: annual leave (15 days) plus ~12 public holidays cost ~18 paid but unavailable hours a month. So
"70% of paid hours" really means ~78% of available hours.

**Why the early numbers will sit around 40–60%:** adult and corporate English clusters in narrow windows.
These are lunch (12:00–13:30 China = 06:00–07:30 SAST) and after work (18:00–21:00 China = 12:00–15:00
SAST). That's about 3–4 strong hours inside an 8-hour salaried shift. Vietnam/Thailand's after-work
window (18:00–21:00 local = 13:00–16:00 SAST) **lands on the same SA hours as China's**, so adding those
markets stacks demand rather than smoothing it. *(Peak-hour pattern is UNVERIFIED. It's the most
important thing your Cambly/italki logs and the pilot should measure.)*
Daytime in-office training in China (09:00–17:00 = 03:00–11:00 SAST) would fill the shift. But that
means early/night shifts in Durban, which raises BCEA night-work rules (allowance and transport,
UNVERIFIED, attorney) and staff safety.

**Fixes to test (not decided):**
- Client contracts with a **minimum committed monthly hours** clause (take-or-pay, billed whether
  used or not) and 24-hour cancellation billing. This is standard in BPO contracts, and your Salesforce/BPO background makes it an easy sell.
- Don't employ tutors until committed hours exist. For the pilot, ask the attorney whether a
  **fixed-term contract tied to a specific client contract** is a valid justification under LRA
  s198B (UNVERIFIED).
- Keep the R16k base, but hire against signed hours, not forecasts.
**Evidence that settles it:** an hourly booking histogram from the pilot (Phase 2), and in Phase 0
which of your own Cambly/italki slots fill.

## 3. LinkedIn is a weak channel into mainland China (confirmed)
LinkedIn suspended new mainland sign-ups in 2021 and shut its China jobs app InCareer on 9 Aug 2023.
It kept only Talent/Marketing/Learning B2B services there.
Sources: https://technode.com/2023/08/10/linkedin-discontinues-incareer-in-china/ ,
https://kr-asia.com/linkedin-shuts-down-incareer-in-china (checked 2026-11-08, HIGH).
**Implication:** Channel #1 works for **Vietnam**, and for multinationals whose regional HR/L&D sits
in Singapore or Hong Kong. It doesn't work for Chinese SMEs. Their reachable channels are WeChat,
Maimai, chambers of commerce and Chinese partners/agents.
**Evidence:** count how many target HR/L&D contacts the prospect-builder can actually find on LinkedIn per market.

## 4. China tax withholding can turn US$12 back into US$10 (likely, needs a China tax adviser)
When a Chinese company pays a foreign service provider, it often withholds **6% VAT** and possibly
**~10% corporate income tax**. Exemptions may apply when the service is performed wholly outside China
and the provider has no Chinese permanent establishment, and a written contract plus correct filings
are needed. Sources are law-firm commentary from 2016–2024 (MED confidence):
https://harris-sliwoski.com/chinalawblog/service-payments-from-china-avoid-the-vat-tax-trap/ ,
https://www.mondaq.com/china/sales-taxes-vat-gst/1484314/risks-to-vat-exemptions-on-cross-border-service-income-in-china ,
https://www.china-briefing.com/news/china-vat-savings-cross-border-transactions/ .
**Impact if deducted:** US$12 × 0.84 ≈ **US$10.08**. That's exactly the rate your plan says is too thin.
Whether the SA–China tax treaty shields this is UNVERIFIED.
**Fix:** quote China prices **net of Chinese taxes (gross-up clause)**, invoice monthly in advance, and
get a China tax adviser's written view before the first China contract. → moves **R13** up the queue.

## 5. "Reliability is the product" depends on a network you don't control (likely)
Zoom has restricted mainland sign-ups to enterprise customers via authorised resellers since 2019.
Teams/Meet/Skype are reported as hard to near-impossible for teaching into the mainland. Tencent
Meeting / VooV is the usual workaround.
Sources: https://technode.com/2019/09/09/china-blocks-us-video-conferencing-tool-zoom/ ,
https://support.learncube.com/en/articles/2468349-can-i-teach-students-in-china ,
https://support.huaweicloud.com/intl/en-us/meeting_faq/international.html (Huawei advises jitter
<50 ms, delay <400 ms, packet loss <5% for overseas users), checked 2026-11-08, MED.
**Evidence that settles it:** 5 test calls Durban → a contact in mainland China on Tencent Meeting/VooV
at 12:00–15:00 SAST, logging latency, jitter and drops. Add a cross-border network clause to client
contracts.

## 6. The escalation schedule is optimistic (possible)
US$12 → US$18 is a 50% rise within 18 months. Corporate L&D buyers on annual budgets are likely to
push back or re-tender. Model the business on **Year-1 price + CPI only**, and treat escalation as
upside. Ask about price expectations in the first 10 buyer calls.

## 7. Positive signals worth keeping
- **Vietnam corporate English is priced higher than you assumed.** Teacher *pay* for in-person
  corporate business English in Hanoi/HCMC is advertised at 550k–1,000k VND/hr (≈US$21–38 at ~26,000
  VND/USD, FX UNVERIFIED), and freelance rates at US$20–30/hr.
  Sources: https://teast.co/employer/axcela-vietnam , https://teast.co/employer/ktdc-business-skills ,
  https://forums.eslcafe.com/job/viewtopic.php?p=1115534 (job ads/forum, MED-LOW). Client prices must
  be higher still. So a **managed online programme at US$16–20 may be credible in Vietnam**, which
  supports leading there.
- South Africa is commonly listed as a "native English" country in Chinese/Thai hiring rules
  (R2, MED-LOW). That's a real edge over Philippine suppliers.
- Your BPO operations background (shifts, QA, KPIs, take-or-pay contracts) fits points 1, 2 and 5 directly.

## Recommendation
1. **Lead with Vietnam corporate/language centres**, with China adult as the second wave via a partner,
   after tax and network tests. The evidence is stronger, LinkedIn works there, and there's no
   withholding-tax trap. *(Owner decision, logged as open in DECISIONS.md.)*
2. **Re-price:** open at US$16 for managed corporate programmes. Use US$12–14 only for language-centre
   subcontracting, with minimum committed hours.
3. **Add to every client contract:** minimum monthly hours, 24-hour cancellation billing, monthly
   prepayment, gross-up for foreign withholding taxes, cross-border network clause.
4. Run the **five evidence tests** above before Phase 2.
