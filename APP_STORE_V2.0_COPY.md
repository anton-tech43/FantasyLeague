# App Store V2.0 Submission Copy

For the V2.0 update submission. The full strategy is in `APP_STORE_STRATEGY.md`; this file is what gets pasted into App Store Connect for the V2.0 version.

WC kicks off **June 11, 2026**. Submit by **June 4** to leave a 7-day Apple review buffer.

---

## Version metadata

**Version number:** `2.0`
**Build number:** Auto-incremented by Xcode at archive time
**Copyright:** `© 2026 Anton Gustafsson` (or your business entity name — match what's set in V1.x)

---

## Subtitle (30 chars max)

> Keep V1's subtitle by default. Switch to a WC variant only during the tournament window. Reset on July 20.

**Default (year-round):**
```
Football talk, simplified
```

**WC variant (optional, June 1 – July 19):**
```
World Cup, simplified
```

Note: changing the subtitle requires resubmission. If you switch to "World Cup, simplified" for V2.0, you'll need V2.1 to switch back on July 20. Easier to keep V1's subtitle and let the screenshots + description carry the WC angle.

---

## Promotional text (170 chars max — editable without resubmission)

**Recommended:**
```
New: pick his World Cup country. Follow his club AND his country all summer. The conversation just got bigger.
```

(108 chars — leaves room for emoji if you want one — recommend ⚽ at start)

**Alternative if you prefer to lead with returning users:**
```
World Cup support is here. Pick his country alongside his club. We'll keep her in the loop for the biggest summer in football.
```

(135 chars)

---

## What's New (4000 chars max — version-specific)

```
World Cup 2026 is coming, and so is Goal Digger's biggest update yet.

New in 2.0:

🇦🇷 Pick his country
48 countries qualified for the World Cup — pick his and we'll deliver the news, match briefs, and conversation hooks every day from squad announcement through the final whistle.

⚽ Follow both his club AND his country
If he watches Arsenal AND England, you get both. The feed mixes club news during the Premier League season and shifts to country news during the World Cup window.

🌍 Brand new onboarding
The country picker is now the heart of the app. Pick his country first (organised by confederation — UEFA, CONMEBOL, AFC, etc.), then optionally add his Premier League club.

📅 World Cup calendar sync
Tap once and his country's matches go straight into your iPhone calendar. So when you mention "the Spain game on Saturday" it's because you actually saw it on your calendar.

🚀 Faster onboarding, prettier transitions
The onboarding flow is tighter and the team-page transitions feel snappier across the app.

Existing users: when you open Goal Digger after updating, we'll ask if you want to add a World Cup country. Pick one — same partner, summer mode. Tap "skip" if he's a club-only kind of guy.

Tournament starts June 11, 2026. We'll be ready. Will you?
```

(~1100 chars — well under the 4000 limit)

---

## Description (4000 chars max)

Two options: (a) keep the V1.0 description as-is, OR (b) update the description to mention WC. Option (b) recommended — it makes the listing feel current for people searching during the WC window.

### Updated full description (recommended for V2.0)

```
Your partner won't stop talking about football. You love him, but you genuinely don't care about the offside rule.

Goal Digger fixes that. And now it covers the World Cup.

— PREMIER LEAGUE COVERAGE —

Pick his team — all 20 Premier League clubs supported. We'll send you short, fun updates only when something actually interesting happens. No spam, no jargon, no boring stats.

— WORLD CUP 2026 —

Pick his country — all 48 qualified nations. From squad announcement through the final whistle, you'll get:
- Daily news about his country's squad
- Match-day briefs at half-time and full-time
- Group-stage and knockout implications, explained like a friend would
- A calendar sync so you actually know when the matches are

— FOLLOW BOTH —

He watches Manchester United AND England? Or Real Madrid AND Argentina (Bellingham, take it away)? Follow both — your feed mixes the two so you can talk about either one in context.

— HOW IT WORKS —

1. Pick his country (48 World Cup nations)
2. Optionally add his Premier League club
3. Get notified when something newsworthy happens
4. Read the 60-second briefing
5. Use the talking points in actual conversation
6. Watch his face when you know about Saka's injury OR the England starting XI

— WHAT YOU GET —

• News updates — transfers, injuries, drama, squad picks — written like your friend is explaining it over coffee, not like a sports reporter
• Match-day cheat sheets — everything you need to know before the game, plus what to say if they win or lose
• Talking points — actual sentences you can say out loud without feeling weird about it
• Quizzes and weekly briefs to learn the team and the tournament

— WHAT WE DON'T DO —

• We don't spam you. Quiet day? No notification. You're welcome.
• We don't use jargon. No "xG", no "false nine", no "pressing triggers."
• We don't send at 3am. Updates come at sensible times.
• We don't track you. No accounts, no ads, no personal data beyond what's needed to send you notifications.

— THE TONE —

"England play Croatia at the opener — it's a tough one. He'll be checking the score every 10 minutes during the match. Ask him if Bellingham's starting tonight."

That's what our updates sound like. Fun, useful, and never condescending.

Goal Digger. Stay in the loop. Win the conversation. Now with World Cup.
```

(~2150 chars — well under the 4000 limit)

---

## Keywords (100 chars max — comma-separated, NO spaces after commas)

V1 was:
```
premier league,football,girlfriend,partner,match day,talking points,arsenal,man united,west ham
```

**V2.0 update — add WC terms, drop club-specific names (they take up budget without much search volume):**

```
premier league,football,world cup,girlfriend,partner,fifa,national team,match day,talking points,boyfriend
```

(98 chars — fits)

**Why the changes:**
- Add: `world cup`, `fifa`, `national team` — top-of-funnel for WC searches
- Add: `boyfriend` — matches the description voice
- Drop: `arsenal,man united,west ham` — these were artifacts of the V1 launch when only 3 clubs were supported. Now all 20 are supported, so naming any 3 misleads search. Better to lean into category terms.

---

## Support URL

Reuse from V1. (If you have one — if not, this is a good prompt to set up a basic landing page or a Notion page at `goaldigger.app/support` with a contact email.)

---

## Privacy policy URL

Required by Apple. Reuse from V1. Should be unchanged for V2.0 — V2.0 doesn't introduce new data collection, just adds a `country_id` field to `device_tokens` which is the same shape as the existing `team_id` field. If your privacy policy already discloses "we store a device token and the team you follow" then adding "or country" doesn't require a policy update. **Verify with the V1 policy text before submitting.**

---

## App age rating

Reuse from V1 (likely 4+ if no UGC). V2.0 adds no new content types — just a different entity type internally. No rating change.

---

## Localizations

V1 ships in English only. V2.0 doesn't change that.

Future: WC-specific country localizations would be a V2.1 candidate — Spanish for Argentina/Mexico/Spain users, Portuguese for Brazil, French for France, etc. Not for this submission.

---

## Pricing

Same as V1: **Tier 10 ($9.99 / £9.99 / €9.99)**. The V2.0 update is FREE for existing customers (App Store updates are always free).

---

## Build configuration

Make sure these are set on the V2.0 build before archiving:

- [ ] `MARKETING_VERSION` (xcconfig) bumped from `1.x` to `2.0`
- [ ] `CURRENT_PROJECT_VERSION` (build number) auto-incremented above the last V1.x build number
- [ ] `SUPABASE_HOST` and `SUPABASE_ANON_KEY` set to PRODUCTION values (not dev) in the Release config of `Configuration.xcconfig`
- [ ] `apsEnvironment` in `GoalDigger-Release.entitlements` set to `production`
- [ ] Push notification entitlement enabled on the App ID in Apple Developer portal
- [ ] No mock data flags set (e.g., `MOCK_API_ONLY=1` should be absent in Release)
