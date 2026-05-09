# Metrics Dashboard — What to Track and Why

Every number ELOS needs to monitor, the formula, the target, and what to do when it's off.

---

## The 5 Numbers That Matter Most (for investor conversations)

| # | Metric | Current | Target (12mo) | Why it matters |
|---|---|---|---|---|
| 1 | **D30 Retention** | — | 35% | Industry benchmark for top fitness apps |
| 2 | **Free → Pro Conversion** | — | 12% | Revenue engine |
| 3 | **Monthly Churn (Pro)** | — | <4% | LTV driver |
| 4 | **CAC (blended)** | — | <$8 | Unit economics |
| 5 | **Workouts Logged / DAU** | — | >1.2 | Engagement / stickiness |

---

## User Acquisition Metrics

### Volume
| Metric | Formula | Target |
|---|---|---|
| New downloads / week | App Store Connect | 200+ at launch, 1K+ at 90 days |
| Account creation rate | Accounts / Downloads | >80% |
| Organic vs. paid split | Source attribution | 70% organic |
| App Store search rank | #1 for "student fitness" | Top 10 in Health & Fitness |
| Referral rate | Referral installs / Total installs | >15% |

### Cost
| Metric | Formula | Target |
|---|---|---|
| CAC (paid) | Ad spend / New paid users | <$20 |
| CAC (blended) | Total acq cost / Total new users | <$8 |
| Cost per install (CPI) | Ad spend / New installs | <$3 |
| ROAS | Revenue from paid cohort / Ad spend | >3× in 12 months |

---

## Activation Metrics

These tell you if new users understand the product:

| Metric | Formula | Target | When it's bad |
|---|---|---|---|
| Onboarding completion | Users who finish setup / new signups | >85% | Shorten onboarding |
| Time to first workout logged | Median minutes after signup | <10 min | Simplify logging flow |
| Time to first meal logged | Median minutes after signup | <15 min | Better onboarding prompt |
| Day-0 action taken | % who log anything on day 0 | >70% | Onboarding prompt issue |
| "Aha moment" hit | % who log workout + meal + habit in first 3 days | >40% | Core loop not clear |

---

## Retention Metrics

The most important category. This is what separates good apps from great ones.

| Metric | Formula | Target | World-class |
|---|---|---|---|
| D1 retention | Users active on day 1 / new users | >55% | 65% |
| D7 retention | Users active on day 7 / new users | >40% | 50% |
| D30 retention | Users active on day 30 / new users | >30% | 40% |
| D90 retention | Users active on day 90 / new users | >20% | 30% |
| Weekly Active Users (WAU) | Unique users with session in 7 days | — | — |
| DAU/MAU ratio | DAU / MAU | >35% | >50% = exceptional |
| Avg session length | Total session time / Sessions | >4 min | >7 min |
| Sessions per DAU | Total sessions / DAU | >1.5 | >2.5 |

### Retention by feature

Track separately — identifies stickiest features:

| Feature | Target 30-day retention uplift |
|---|---|
| Users who log workouts 3+ times/week | +22% vs. baseline |
| Users who log nutrition daily | +18% vs. baseline |
| Users who use Canvas sync | +31% vs. baseline |
| Users who complete onboarding 100% | +28% vs. baseline |
| Users who join with a referral code | +35% vs. baseline |

---

## Engagement Metrics

How deeply users use the product:

| Metric | Formula | Target |
|---|---|---|
| Workouts logged / active user / week | Total workouts / active users / weeks | >1.5 |
| Meals logged / active user / day | Total meals / active users / days | >2.0 |
| Habit completion rate | Habits completed / habits created | >55% |
| AI parses / user / week | Total AI parses / active users / weeks | >3 (free), >8 (Pro) |
| Sleep logs / user / week | Total sleep logs / active users / weeks | >4 |
| Features used per user (breadth) | Total distinct features used / users | >3.5 |

### Power user definition
A power user uses ELOS on ≥5 days per week and logs in at least 3 modules.
Target: **20% of MAU are power users.**
Power users are your best referral source and most vocal advocates.

---

## Monetization Metrics

| Metric | Formula | Target |
|---|---|---|
| Free → Pro conversion | Pro users / Total registered | 10–15% |
| Monthly → Annual upgrade | Annual subs / New monthly converts | 40% |
| Monthly churn (Pro) | Cancelled Pro / Total Pro | <4% |
| Annual churn (Pro) | Annual non-renewals / Total Annual | <20% |
| ARPU (monthly) | MRR / Total Pro users | >$5.50 |
| ARPPU | MRR / Paid users | >$6.50 |
| MRR | Sum of monthly recurring revenue | See projections |
| ARR | MRR × 12 | — |
| Net Revenue Retention | MRR end / MRR start (same cohort) | >100% (expansions) |

### Churn reasons to track (exit survey, required when cancelling)
- Too expensive
- Not using it enough
- Missing a specific feature
- Found a better app
- Seasonal (summer break, etc.)
- Technical issue

**Action by reason:**
- "Too expensive" → Annual plan offer at 40% off
- "Not using it enough" → Re-engagement campaign 30 days prior
- "Missing feature" → Add to roadmap tracking, follow up when shipped

---

## Revenue Metrics

| Metric | Formula | Target (12mo) |
|---|---|---|
| MRR | Sum of all monthly subscription fees | $10K |
| ARR | MRR × 12 | $120K |
| MRR growth rate | (MRR_this - MRR_last) / MRR_last | >15%/month |
| Gross revenue | Total payments collected | — |
| Net revenue | Gross - App Store cut (15–30%) | — |
| LTV | ARPU / Churn rate | >$60 |
| LTV:CAC | LTV / CAC | >8:1 |
| Payback period | CAC / (ARPU × Gross margin) | <3 months |

---

## Product Health Metrics

| Metric | Formula | Target |
|---|---|---|
| App Store rating | Average of all reviews | >4.7 ⭐ |
| NPS | % Promoters - % Detractors | >50 |
| Crash rate | Crashes / Sessions | <0.1% |
| App Store review velocity | New reviews / week | >5 positive |
| Support ticket volume | Tickets / 1000 MAU | <3 |
| P0 bug resolution time | Time from report to fix | <24 hours |
| API latency (p95) | 95th percentile API response | <200ms |

---

## Cohort Analysis Template

Run this monthly for every acquisition cohort (users acquired in same month):

```
Cohort: [Month/Year acquired]
Size: [N users]

               Month 0  Month 1  Month 2  Month 3  Month 6  Month 12
Active users:   100%     X%       X%       X%       X%       X%
Free users:     90%      X%       X%       X%       X%       X%
Paid users:     10%      X%       X%       X%       X%       X%
Revenue/user:   $0       $X       $X       $X       $X       $X
Cumulative LTV: $0       $X       $X       $X       $X       $X
```

**Red flag**: If cohort revenue in month 3 is below your CAC, you have a unit economics problem.

---

## Social & Virality Metrics

| Metric | Formula | Target |
|---|---|---|
| Viral coefficient (K-factor) | Invites sent × conversion rate | >0.5 (ideally >1) |
| Referral rate | Referred installs / Total installs | >15% |
| Instagram mentions / week | Manual + social listening | >20 |
| TikTok views (ELOS hashtag) | TikTok analytics | 100K+ |
| App Store search impressions | App Store Connect | Growing MoM |
| Press mentions | Earned media | 1/month target |

---

## Investor-Ready Reporting Cadence

**Weekly (internal)**
- New downloads, DAU, WAU, MRR
- Any P0 bugs or App Store issues

**Monthly (board/investors)**
- Full cohort retention table
- MRR, ARR, net new paid, churn
- CAC by channel
- Top 3 user feedback themes
- Feature shipped this month

**Quarterly**
- Full P&L
- LTV:CAC by cohort
- NPS score (survey 10% of users)
- Competitive landscape update
- Roadmap review
