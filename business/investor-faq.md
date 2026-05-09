# Investor FAQ

Every hard question an investor will ask. Answered directly, without spin.

---

## About the Founder

**Q: You're in high school. Why should we trust you with $500K?**

I built a production-quality iOS app — native SwiftUI, SwiftData, AI integration, full feature parity across 5 modules — in less than a year, solo, while going to school. I didn't use a template. I didn't hire anyone. That's the quality bar I operate at before I have resources.

The argument against betting on a high school founder is maturity. The argument for is leverage: I am simultaneously the CEO, the product manager, the engineer, the designer, and the primary user. Most seed-stage teams of 3 can't ship what I shipped solo. You're not taking a maturity risk — you're taking an execution bet. And I've already executed.

**Q: What happens when you go to college?**

I'm planning to defer or take a gap year if ELOS reaches the $700K ARR threshold before application season. If I go to college, I will continue building ELOS — plenty of successful founders (Zuckerberg, Dell, Gates) built companies in college. The product is designed to be maintainable: clean architecture, offline-first, documented codebase. I hire with seed money specifically to reduce founder-single-point-of-failure risk.

**Q: You're 17. Can you legally sign a SAFE or take investment?**

Yes, with parental co-signature on any legal agreements until I turn 18. This is standard for student founders. We can structure around it. Dorm Room Fund and Contrary Capital have both done this.

**Q: What's your unfair advantage?**

Three things:
1. I am the customer. Every decision I make is validated by a real user with a real use case — me.
2. I'm building in a moment when AI API costs have dropped 97%. The feature set that would've been a $30/mo product two years ago costs me $0.001 per AI call.
3. My story is the marketing. "High school student builds app to replace 6" is a TechCrunch headline, a Product Hunt front page, and a TikTok hook — simultaneously. No marketing budget required.

---

## About the Market

**Q: MyFitnessPal has 200 million users. Why would anyone switch?**

MyFitnessPal is a food diary app with a broken UX, owned by a private equity firm that hasn't invested in product since 2020. It has zero workout integration, zero academic integration, and no AI. Its primary user base is 35–55 year old women on diets. It's not competing for my user.

More specifically: my user (16–22, competitive student athlete) doesn't use MyFitnessPal. They find it overwhelming and irrelevant. I'm not taking MFP users — I'm capturing the next generation before MFP gets them.

**Q: What if Apple builds this into Health or Fitness apps?**

Apple Health is a data layer, not an opinionated app. Apple Fitness+ is cardio video content. Apple has not and will not build a LMS sync, an academic planner, AI meal parsing, or a workout logging UI. Apple's strategy is to own the data layer and let third-party apps build on top of it. ELOS is one of those apps.

Apple's App Store editorial team has specifically featured "student health" and "fitness logging" categories in back-to-school promotion windows. Apple is a distribution partner, not a competitor.

**Q: What if a well-funded competitor copies ELOS?**

If we're at the stage where a well-funded competitor is copying us, we've already won distribution. They'll be 12–18 months behind on data (user history can't be copied), behind on community trust, and behind on the "authentic student founder" brand story that no PE-backed company can replicate.

The real moat is data network effects + category ownership. The user who has 6 months of workout history, sleep data, and grade correlations in ELOS isn't switching. The switching cost grows every day.

---

## About the Business Model

**Q: Will students actually pay $7/month?**

Yes. The evidence:
- Students pay $10/month for Spotify without complaining
- Students pay $9.99/month for Apple Music
- Students with fitness goals pay $9.99–$19.99/month for MyFitnessPal Premium
- Our beta users (n=50) rated "willingness to pay" at 3.8/5 before they'd even seen the Pro paywall

The key is positioning: we're not "$7/month for an app" — we're "$7/month to replace $25+ in apps you're already paying for." Net savings framing converts better than price framing.

Annual plan removes the monthly friction entirely. A student who pays $59.99 once in August (back to school) doesn't think about it again until next August.

**Q: How do you prevent churn when school is out (summer)?**

Seasonality is real in the student market. Mitigation:
1. Users who have workout history don't cancel — they're tracking gains
2. Summer camp / summer sports users are active users, just in different routines
3. Annual plan subscribers don't churn in summer — they already paid
4. We push a "summer mode" feature in May that adjusts to summer training schedules

Target: Annual plan mix at 55% by Month 12. Annual subscribers have 4× lower churn than monthly.

**Q: The App Store takes 30%. How does that affect the model?**

Year 1: 30% cut. Year 2+: 15% cut (Apple Small Business Program, applies under $1M annual revenue). The model is fully baked with these cuts reflected. Our 90% gross margin at the product level becomes ~80% after App Store, still top-quartile for consumer software.

Team/B2B revenue can be invoiced directly, bypassing the App Store entirely for that revenue stream.

**Q: What's the path to $1M ARR?**

Base case: Month 22 (just under 2 years). Requires:
- 5,000 Pro subscribers at $6.99/month blended ARPU of ~$6 = ~$30K MRR consumer
- 25 team contracts at average $1,800/year = ~$3,750/month B2B
- Combined: ~$34K MRR → ~$400K ARR at 22 months

To reach $1M ARR: ~12,000 Pro subscribers + 40 team contracts, achievable in Month 30–33.

---

## About the Product

**Q: How does the AI meal parsing actually work?**

User types or speaks "2 eggs, toast, and OJ." That text goes to Claude via Anthropic API. The prompt instructs Claude to return a structured JSON object with food items, estimated calories, protein, carbs, and fat. The response parses in <1 second. Cost: $0.0005–0.002 per parse.

The accuracy is good enough — it's not intended to be a food scale, it's intended to be better than not logging at all. Users who log approximately are more consistent than users who give up because it's too precise.

At 3 parses/day for free users (limit trigger), our AI cost per free user is ~$0.015/day = $0.45/month. Pro users (unlimited parses) average 6–8 parses/day = $0.90–$1.20/month in AI costs. Fully covered in the $6.99 price point.

**Q: Why not build this as a web app? Why iOS-only?**

iOS-native is a deliberate strategic choice, not a constraint:
1. App Store distribution is the only scalable discovery channel for consumer apps
2. iOS users monetize at 2–3× the rate of Android or web users
3. SwiftUI + SwiftData gives us capabilities (offline-first, haptics, HealthKit, widgets) that web can't match for a gym use case
4. App Store featuring is worth $0 in spending but equivalent to millions in acquisition for featured apps

Android comes in Year 2 after iOS is profitable. The core architecture is clean enough to cross-compile key logic.

**Q: What's the risk if Anthropic raises API prices?**

We've designed the product so the AI is a feature enhancer, not a core dependency. If AI costs triple:
- Free tier goes from 3 → 2 parses/day
- Pro tier remains unlimited (still profitable at 2× current cost)
- We explore open-source models (Llama, Mistral) for meal parsing specifically — it's a structured extraction task, not reasoning

We also have heuristic fallback parsing (keyword matching + portion estimation) built in for offline gym scenarios. The AI is additive, not load-bearing.

**Q: The Canvas LMS integration — can you actually get approval for that?**

Canvas (Instructure) has a public OAuth API that any developer can use. Students can authenticate with their own Canvas account using their school credentials. ELOS doesn't need school IT approval to read a student's own assignments and grades — the student grants OAuth access themselves, same as connecting Spotify to any third-party app.

For the Team/Enterprise tier, we pursue formal Instructure partnership (they have a marketplace). But for consumer users, it works today with no approval needed.

---

## About the Competition

**Q: Whoop has $200M in revenue and has a hardware moat. Why is ELOS even comparable?**

We're not comparable. WHOOP is a hardware company selling to 30-year-old athletes for $30/month + $200 hardware. ELOS is a software company selling to 17-year-olds for $7/month, no hardware.

The comparison is useful because it shows the ceiling: there's a market willing to pay serious money for athletic performance data. ELOS is the entry-level version of that market — accessible, affordable, software-only, with academic integration that WHOOP will never build.

**Q: Could Notion or Strava pivot into this space?**

Notion is a blank canvas enterprise collaboration tool. Pivoting to opinionated fitness/academic tracking would cannibalize their core "flexibility" brand. They won't do it.

Strava is a social network for endurance athletes (runners and cyclists). Their core feature — GPS route tracking — is irrelevant to weightlifting and has no academic component. Their community is 30–45 year-old adults. Pivoting to student athletes is brand destruction for them.

Neither company is incentivized to fight in our category.

---

## About the Investment

**Q: $4M post-money cap — how did you arrive at that number?**

Comparable pre-revenue seed rounds for consumer mobile:
- App with working MVP + beta users: $3–5M post-money
- Founding team solo, no institutional backers: haircut vs. team of 3
- Unique story / category creation: premium vs. commodity app

$4M is the midpoint of the range where seed investors get a real ownership stake (~12.5% for $500K) without the cap being insulting to either party. It reflects the risk-adjusted value: working product exists, but no revenue yet.

If you believe in the $42M SOM (3-year target) and a 5× revenue multiple, the Series A at $1M ARR is a $5M+ round at $25M+ pre-money. $4M entry gives a seed investor 2.6× on dilution alone, before the multiple.

**Q: Why $500K? Why not raise more or less?**

Less ($200K): Doesn't cover an iOS hire + growth hire + 18-month runway. Forces me to stay solo, which is the real execution risk.

More ($1M): Dilution is too high at a $4M cap for unproven revenue. Over-raising creates pressure to grow faster than the product is ready.

$500K at $4M post: 12.5% dilution. Gets us to Series A threshold. Clean, defensible, aligned with what seed investors can write for a pre-revenue solo founder.

**Q: What's the exit strategy?**

This isn't built to flip. But strategic acquirers exist:
1. **Apple** — Student health + HealthKit depth is exactly the "apps we acquire to deepen the ecosystem" play
2. **Chegg** — Student digital tools company, already in the student acquisition business
3. **Nike Training Club / Under Armour** — Both have digital fitness apps; ELOS is 3 years of product roadmap ahead of them in the student segment
4. **Instructure (Canvas)** — We're the consumer layer on top of their product; acquisition locks in defensibility
5. **Strava** — Student athlete market + workout logging is the one category gap they have

Realistic exit multiples at $1.5M ARR: 6–10× ARR = $9M–$15M. At $5M ARR: 8–12× = $40–60M. Target: IPO or strategic acquisition at $100M+ in Year 5–7.

**Q: If I invest, when do I get my money back?**

Target Series A in Month 22–24 at $1M ARR run rate. Series A investors typically return seed money at 3–5× through their own secondary. Full liquidity at acquisition or IPO.

This is an 18–24 month seed → Series A path, not a quick flip. If that timeline doesn't work for your fund structure, we're probably not a fit at this stage.

---

## PR Pitch Template (for press outreach)

Use this as the base pitch to journalists:

> **Subject: High school student builds app replacing 6 — and it's actually good**
>
> Hi [Name],
>
> I'm a [grade] student at [school] who got frustrated using MyFitnessPal, Strava, Notion, a planner app, a habit tracker, and my school's Canvas portal every morning before practice. So I built one app that does all of it.
>
> ELOS is a native iOS app for competitive student athletes — it logs workouts, parses meals with AI, syncs with Canvas LMS for assignments, and shows everything in a single morning dashboard. I built it alone, in Swift, in [timeframe].
>
> It's not a school project. It's on the App Store. It has real users. I'm raising a seed round.
>
> Happy to do a 15-minute call or send screenshots. The code is on GitHub: github.com/FrankieBiz/ELOS-iOS
>
> — Frank Aguilar

Target journalists:
- Business Insider: "Gen Z Founders" section (bi@businessinsider.com)
- TechCrunch: Startups submissions form (techcrunch.com/submit)
- The Verge: Tips email
- Local newspaper: Always says yes; regional press often gets picked up nationally
- School newspaper: First outlet; gives you a "first press mention" to reference in larger pitches
