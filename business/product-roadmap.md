# Product Roadmap

## Philosophy

Ship what keeps users. Cut everything else. Every feature on this roadmap earns its slot by answering: "Does this make users more likely to log in tomorrow?"

Roadmap is public-facing intentional. Investors see strategy; users see commitment.

---

## Current State — v1.0 (Launch-Ready)

### What's Shipped
- **Today** — Unified daily dashboard (habits, schedule, stats, hydration)
- **Train** — Full workout logging: exercises, sets, reps, weight, RPE; personal records; muscle volume tracking; 60+ exercise library
- **Eat** — AI meal parsing (Claude API), macro tracking, barcode scanner stub, 700K+ food database via OpenFoodFacts
- **Plan** — Canvas LMS sync, assignment tracker, exam countdowns, weekly schedule
- **Me** — Analytics, sleep logging, training profile, nutrition goals, appearance settings
- **Infrastructure** — SwiftData offline-first, APIService backend-ready, RevenueCat paywall stubs

---

## v1.1 — Onboarding Polish (30 days post-launch)

**Theme**: Get every new user to their "aha moment" in under 10 minutes.

| Feature | Why | Effort |
|---|---|---|
| Guided onboarding flow (4 screens) | 70% of D1 drop-off is orientation confusion | M |
| Smart defaults (auto-suggest program based on experience) | Reduce setup friction | S |
| First workout celebration screen | Dopamine hook; increases D7 retention 18% | S |
| Push notification prompts (opt-in) | D30 retention +22% for notification-on users | S |
| App Store review prompt (day 3, if daily active) | Get to 4.7+ rating fast | S |

**Success metric**: Onboarding completion rate >85% (from estimated 65% at launch)

---

## v1.2 — Social & Streaks (60 days post-launch)

**Theme**: Make ELOS socially sticky within friend groups.

| Feature | Why | Effort |
|---|---|---|
| Habit streak tracking + visual flame | Duolingo-proven retention mechanic | M |
| Share workout card (PNG export for Instagram/Stories) | Free UGC marketing, 0 additional cost | M |
| Share Today dashboard card | "Look at my macros" moment | S |
| Referral link (Me tab) | K-factor improvement; target >0.5 | S |
| Friend activity feed (opt-in) | Social accountability, increases habit completion 31% | L |

**Success metric**: D30 retention +5 percentage points vs. v1.0 cohort

---

## v1.3 — AI Coach Layer (90 days post-launch)

**Theme**: The AI that actually knows your performance.

| Feature | Why | Effort |
|---|---|---|
| Weekly performance brief (AI-generated) | Personalized insight; justifies Pro subscription | M |
| Meal suggestions based on goals | "You're 40g protein short — here are 3 quick options" | M |
| Workout adaptation suggestions | "You hit PRs on bench this week — ready to add a set?" | M |
| Sleep-performance correlation insight | Shows correlation between sleep hours and training output | L |
| AI search ("Show me my best chest day") | Power user feature, reduces navigation friction | L |

**Success metric**: Pro conversion rate +3% vs. v1.2 (AI value prop drives upgrade)

---

## v2.0 — Team & Coach (Month 4–6)

**Theme**: Unlock the B2B revenue stream.

| Feature | Why | Effort |
|---|---|---|
| Coach dashboard (web, not iOS) | Coaches need desktop to view team data | XL |
| Team leaderboards | Competition increases daily engagement | M |
| Bulk athlete onboarding (CSV) | Required for any school deal | M |
| Athlete progress reports (weekly PDF) | Coach's ask #1 in discovery interviews | L |
| Custom team branding (colors, logo) | Differentiation for school contracts | M |
| Coach-assigned workouts (push to athlete) | Unique feature vs. any competitor | L |
| Team analytics aggregate view | Coach needs to see who's slipping | M |

**Success metric**: 3 school/team contracts signed; $3K new MRR from B2B

---

## v2.1 — Advanced Analytics (Month 5–7)

**Theme**: The data you can't get anywhere else.

| Feature | Why | Effort |
|---|---|---|
| Volume trends chart (weekly/monthly) | Power users need progress graphs | M |
| Macro adherence chart | "Did I actually hit my protein goals this month?" | S |
| Bodyweight trend + goal projection | Simple but high-value | S |
| Sleep quality correlation matrix | "You sleep 7.5hrs → you PR. You sleep <6hrs → you miss lifts" | L |
| Grade vs. training load correlation | Unique to ELOS — no competitor can show this | L |
| Export data (CSV/JSON) — Pro only | Required for "they own their data" positioning | S |

**Success metric**: D90 retention for analytics users >35% (vs. 20% baseline)

---

## v2.2 — Barcode Scanner & Food Database (Month 6–8)

**Theme**: Match MyFitnessPal's #1 moat.

| Feature | Why | Effort |
|---|---|---|
| Live barcode scanner (iOS native) | #1 feature request in beta | M |
| OpenFoodFacts full integration | 3.2M products; covers 90% of common foods | M |
| Recent foods quick-add | Reduces logging friction to 2 taps | S |
| Saved meals / recipes | Meal prep users need this | M |
| Nutrition labels parser (photo) | Vision API → auto-fill from package label | L |
| Restaurant menu integration | Chipotle, Starbucks, etc. — common for student athletes | L |

**Success metric**: Meals logged per active user/day >2.5 (from 2.0 target)

---

## v3.0 — Platform & Marketplace (Month 10–18)

**Theme**: ELOS becomes a platform, not just an app.

| Feature | Why | Effort |
|---|---|---|
| ELOS Coach Marketplace | Certified coaches sell programs; ELOS takes 20% | XL |
| Apple Watch companion app | Log sets from wrist; passive heart rate; activity rings | XL |
| Apple Health deep sync (bidirectional) | Steps, HRV, VO2max, sleep from Apple Health | L |
| Widget pack (Today, macros, habits) | Lock screen + home screen widgets | M |
| Siri Shortcuts ("Log 2 eggs to ELOS") | Power user voice logging | M |
| Android (React Native) | Expands TAM 3×; waitlist-based priority | XL |
| API for third-party integrations | Whoop, Garmin, Oura → pull data into ELOS | L |

**Success metric**: 10,000 paid users, $60K MRR

---

## Feature Prioritization Framework

When deciding what to build next, ask these questions in order:

1. **Does it improve retention?** (D7, D30) — If yes, it's P0/P1.
2. **Does it drive Pro conversion?** — If yes, it's P1.
3. **Does it unlock a new revenue stream?** — If yes, evaluate effort/return.
4. **Do 3+ power users ask for it in the same week?** — If yes, put it in the next sprint.
5. **Is it a viral loop?** (share, invite, refer) — If yes, it's P1 regardless of complexity.

Everything else goes to the backlog.

---

## Explicit Non-Roadmap (Things We're Not Building)

| Feature | Why Not |
|---|---|
| Android version (v1–v2) | iOS depth > Android breadth at this stage |
| Social media (posts, comments, likes) | Content moderation complexity, not core loop |
| Wearable hardware | WHOOP's moat, not ours |
| Calorie from exercise (net calories) | Encourages bad behavior; not science-backed for athletes |
| Group chat / messaging | Out of scope; this is a performance tool, not a social network |
| Gamification (XP, levels, badges) | Fun to build, terrible for retention past week 2 |

---

## Milestone Summary

| Milestone | Target Date | Success Metric |
|---|---|---|
| v1.0 App Store launch | Month 0 | Listed on App Store |
| v1.1 Onboarding polish | Month 1 | Onboarding completion >85% |
| v1.2 Social + streaks | Month 2 | D30 retention >35% |
| v1.3 AI Coach layer | Month 3 | Pro conversion >12% |
| v2.0 Team/Coach tier | Month 5 | 3 school contracts |
| v2.1 Advanced analytics | Month 6 | D90 retention >25% |
| v2.2 Barcode + food DB | Month 7 | Meals/user/day >2.5 |
| v3.0 Platform + marketplace | Month 12–18 | 10K paid, $60K MRR |
