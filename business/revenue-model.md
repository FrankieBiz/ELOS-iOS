# Revenue Model & Unit Economics

## Pricing Tiers

### ELOS Core (Free)
**Goal**: Maximum top-of-funnel, habit formation, word-of-mouth

Includes:
- Unlimited workout logging
- Manual food logging (breakfast, lunch, dinner, snacks)
- Up to 5 habits
- 7-day data history
- Today dashboard
- Basic personal records

Hard limits that drive upgrade:
- AI meal parsing: **3/day** (shows value → creates want)
- History: **7 days** (free; Pro = unlimited)
- Charts/analytics: **locked**
- Canvas sync: **locked**
- Templates: **3 max**

---

### ELOS Pro — $6.99/month or $59.99/year
**Goal**: Core revenue engine, targeting serious users

Everything in Core, plus:
- Unlimited AI meal parsing
- Barcode scanner (OpenFoodFacts)
- Full data history + export (CSV/JSON)
- Advanced analytics (volume trends, macro adherence, sleep correlation)
- Unlimited workout templates
- Canvas LMS sync (assignments + grades)
- Custom habit categories + colors
- Priority customer support
- Early access to new features

**Pricing rationale:**
- $6.99/month = $83.88/year
- $59.99/year = $5/month effective → 29% discount
- Below MyFitnessPal Premium ($19.99/mo), below WHOOP ($30/mo)
- Positioned as "less than a gym protein bar per week"
- Annual plan target: 60% of Pro users (improves LTV dramatically)

---

### ELOS Team — $4.99/user/month (billed annually to school/coach)
**Goal**: B2B revenue + institutional distribution

Minimum 5 users, billed annually.

Includes everything in Pro, plus:
- Coach/admin dashboard
- Team leaderboards
- Athlete progress reports (weekly PDF)
- Bulk CSV onboarding
- Custom team branding
- Dedicated onboarding call
- SLA support

**Target buyers:**
- High school athletic directors
- Club sports coaches (AAU basketball, travel baseball, swim teams)
- College strength & conditioning coaches
- Private performance coaches / personal trainers

**Sales motion:** Direct outreach to coaches → free 30-day team trial → annual contract

---

## Unit Economics

### Consumer (Pro) Cohort

```
Average Revenue Per User (ARPU):
  Monthly Pro:  $6.99/mo × avg 8 months = $55.92
  Annual Pro:   $59.99 flat
  Blended ARPU: ~$58/year

Customer Acquisition Cost (CAC):
  Organic (target: 70% of users): ~$2
  Paid (target: 30% of users):    ~$18
  Blended CAC:                    ~$6.80

Lifetime Value (LTV):
  Avg subscription length: ~14 months
  Monthly churn: ~5% (target: <3% at maturity)
  LTV = $58 × (14/12) = $67.67
  
LTV:CAC Ratio: $67.67 / $6.80 = 9.96:1   ← Target: >3:1 (we're at 10:1)

Payback Period: ~6 weeks

Gross Margin: 87% (App Store takes 15% after first year, minimal infra cost)
```

### Team Cohort

```
Average team size: 18 athletes
Revenue per team: 18 × $4.99 × 12 = $1,077/year
CAC (direct sales outreach): ~$150/team
LTV (avg team contract: 2.5 years): $2,693
LTV:CAC: 17.9:1

Gross margin: 82% (account manager cost factored in)
```

---

## Revenue Mix (Target at Maturity)

| Stream | Year 1 | Year 2 | Year 3 |
|---|---|---|---|
| Pro Monthly | 55% | 40% | 30% |
| Pro Annual | 30% | 40% | 45% |
| Team/B2B | 5% | 15% | 20% |
| API / Data | 0% | 0% | 5% |
| Partnerships | 10% | 5% | 0% |

**Why shift toward annual and B2B over time:**
- Annual reduces churn (users don't cancel mid-year)
- B2B has higher ACV and lower churn
- Data licensing (anonymized, aggregated) becomes feasible at 100K+ users

---

## Conversion Funnel Targets

```
App download
  → Account created:           80% (goal: reduce friction)
  → 1st workout logged:        65% (goal: onboarding flow quality)
  → D7 retention:              45% (goal: habit formation mechanics)
  → D30 retention:             32% (goal: best-in-class: 35%)
  → Hits AI parse limit (free): 55% of D30 users
  → Sees Pro upgrade prompt:    55%
  → Converts to Pro (monthly):  12%
  → Converts to annual at renewal: 55%
```

**Most important conversion trigger**: AI meal parsing limit hit.
When a free user hits the 3/day limit, conversion rate is 3× higher than the app-wide average. This is the "aha moment" paywall.

---

## Paywall Design Principles

1. **Show before blocking**: Let users see the AI parse result before asking them to upgrade
2. **One-tap upgrade**: App Store payment sheet, no form filling
3. **7-day free trial on annual**: Removes friction, increases annual preference
4. **No dark patterns**: If they cancel, give them their data export immediately — this builds trust and reduces App Store reviews anger

---

## Future Revenue Streams (Year 3+)

### ELOS Coach Marketplace
- Certified coaches create programs on ELOS
- ELOS takes 20% of program sales
- Coaches get distribution; ELOS gets content moat

### Brand Partnerships
- Supplement brands (Optimum Nutrition, Legion Athletics)
- Performance gear (Nike Training, Under Armour)
- Model: Sponsored meal templates, not banner ads
- Never sell user data — sell brand-created content placements

### ELOS Data Intelligence (enterprise)
- Anonymized, aggregated trends:
  - "What does a high-performing student's nutrition look like during AP exam season?"
  - Sold to: Sports nutrition brands, university wellness programs, insurance companies (wellness programs)
- FERPA/COPPA compliant
- Opt-in only, no PII

### White-Label Licensing
- License ELOS platform to school districts as their official student wellness app
- Per-student annual fee: $8–15/student
- 1,000-student school = $8,000–15,000/year/school
