# Goal Digger — Product Requirements Document (PRD)

**Version:** 2.0
**Date:** April 6, 2026
**Source brief:** `goaldigger-product-brief.txt` (April 2026)
**Companion documents:** [BUILD_PLAN.md](./BUILD_PLAN.md) | [AGENT_CONTRACTS.md](./AGENT_CONTRACTS.md) | [PRODUCT_BRIEF_INTEGRATION.md](./PRODUCT_BRIEF_INTEGRATION.md)

---

## 1. Overview

Goal Digger is a mobile app (iOS) for girlfriends of football fans who want to feel more connected to their partner without becoming football fans themselves. The app delivers curated talking points and live football news, filtered by relevance and framed around how her boyfriend probably feels about it.

This is not a sports app. It is a relationship app that happens to use football as its medium.

Premier League coverage is the foundation. World Cup 2026 is the primary launch target (fast-follow after PL v1).

## 2. Target User

Women in relationships with football fans who have little to no interest in football themselves. She doesn't want to learn football. She wants to feel included, hold a conversation, and show her boyfriend she pays attention. The app gives her that quickly, warmly, and without judgment.

## 3. Core Features

### 3.1 Personalised Onboarding

She enters her name and his name during onboarding. She picks his favourite team from the available list (3 teams in v1). She selects her engagement tier. Names are stored locally on device only (never sent to server) and used to personalise in-app content.

### 3.2 Content Tiers

The AI writes three versions of every story. She self-selects during onboarding and can change in settings anytime.

| Tier | Label | Description | Max notifications/day |
|------|-------|-------------|----------------------|
| 1 | "Just enough to get by" | Match day heads-up and one key talking point | 1 |
| 2 | "Came to impress" | Regular news and talking points through the week | 2 |
| 3 | "The one he brags about" | Everything including deep news, stats context and transfer rumours | 3 |

### 3.3 News Updates (When Newsworthy)

The app sends a push notification when something genuinely newsworthy happens related to the user's chosen team. This includes transfers, injuries, off-pitch drama, manager quotes, and trending stories. If nothing meaningful is happening, no notification is sent — the app should never spam the user. The tone should be casual, fun, and easy to understand—not dry sports journalism.

### 3.4 Game Day Talking Points

On match days, the user receives an additional push notification with short, digestible talking points about the upcoming game. This could include recent form, key players to watch, head-to-head stats, and conversation starters.

### 3.5 Home Screen Feed

The Home Screen serves as the central notification feed — a scrollable timeline of all updates for the user's selected team. Content depth scales by tier. Users can dismiss push notifications when the timing is bad and catch up later in the app.

### 3.6 Tap-Through Detail View

When the user taps an item in the feed (or a push notification), they land on a detail screen with more context, deeper talking points, and background info.

### 3.7 Context Cards

**His Team Page:** One page per club with club name/nickname, stadium, manager, top 3 players, biggest rival, fun fact, current season summary. All written in GoalDigger voice.

**Player Cards:** Tappable from any player name in the feed. Shows name, age, position in plain English, why fans care about him, his vibe (fan favourite, controversial, etc.), and current form. 10-second read.

**Match Day "Ones to Watch":** Three key players per match with context. Shown on match day in the app and teased in the 9am notification.

### 3.8 Talking Point Engine

Before writing any talking point, the AI checks: what happened, how significant it is for his team, and how he probably feels about it. Context pressure flags (title race, relegation, bad form, cup run, etc.) change the emotional weight of every talking point. See BUILD_PLAN.md for flag definitions.

## 4. Notification Strategy

The golden rule: she should never think "why did I get this." Every notification tells her what to do with the information — a talking point, a mood heads-up, or an action.

| Type | Tier 1 | Tier 2 | Tier 3 | Timing |
|------|--------|--------|--------|--------|
| Match day heads-up | Yes | Yes | Yes | 9am on match day |
| Result notification | Yes | Yes | Yes | Within 5-10 min of full time (any time of day) |
| Big news alert | No | Yes | Yes | When it breaks (max 1/day) |
| Weekly summary | No | Yes | Yes | Tuesday or Wednesday |
| Monthly summary | Yes | No | No | Once a month |

Notifications should be short and punchy (1-2 sentences max), with a "tap for more" experience. Result notifications are sent regardless of time — if he's out at the game or the bar, she wants to know what mood he's coming home in.

## 5. Data Sources

The app pulls data from multiple sources to create engaging, well-rounded updates:

- **Official APIs** — Football data APIs (e.g., football-data.org, API-Football) for fixtures, scores, standings, and player stats.
- **News sites** — AI reads and summarizes articles from major football news outlets (e.g., BBC Sport, Sky Sports, The Athletic).
- **Social media (v1.2)** — Team Instagram accounts, player accounts, and football influencers for trending stories and off-pitch content. Deferred from v1 due to complexity vs. value tradeoff.

The Claude API (Anthropic) processes and summarizes all incoming data into short, engaging, girlfriend-friendly language.

## 6. User Flow

1. Download the app from the App Store.
2. **Welcome** — "You're here. He has no idea. Let's get you ready."
3. **Her name** — "First things first, what's your name?"
4. **His name** — "And what's his?"
5. **What to follow** — Premier League (WC 2026 coming in fast-follow update)
6. **Team Selection** — "Who does [his name] support?" — Pick one team (Arsenal, Man United, or West Ham).
7. **Tier Selection** — "How far do you want to take this?" — Choose engagement depth.
8. **Enable Notifications** — "We'll handle the rest. Just let us in."
9. **First Talking Point** — Land on today's most relevant content immediately.
10. **Home Screen** — Feed of all updates for the selected team, depth scaled by tier.
11. **Receive Notifications** — Frequency and types based on tier selection.
12. **Tap Notification** — Opens detail view with talking points and context.
13. **Context Cards** — Tap team name for his team page, tap player names for player cards.

## 7. Technical Architecture

### 7.1 Frontend

- **Platform:** iOS (Swift / SwiftUI)
- **Local storage:** UserDefaults for preferences + SwiftData for content caching

### 7.2 Backend

- **Server:** Supabase (PostgreSQL + Edge Functions + auto REST API)
- **AI Processing:** Claude API (Anthropic) processes and summarizes content from data sources into engaging talking points
- **Push Notifications:** Apple Push Notification Service (APNs) via the backend
- **Scheduled Jobs:** Supabase `pg_cron` + Edge Functions to trigger news updates and game-day notifications

### 7.3 Data Pipeline

Data is fetched **per team**, not per user. In v1 with 3 teams, this keeps API and AI costs flat regardless of user count.

1. Scheduled jobs pull data from APIs and news sources for each of the 3 teams
2. Claude API processes raw data into short summaries and talking points
3. Multiple AI review bots validate content quality and tone before publishing
4. Approved content is stored in the database, tagged by team
5. Push notifications are sent to users based on their selected team
6. Users tap through to see the full detail view

## 8. Monetization

- **v1:** Paid app — $10 on the App Store (one-time purchase, no in-app purchases)
- **Future:** Explore subscription model if content expands (e.g., more teams, live updates)

## 9. Scope & Limitations (v1)

- Only 3 teams available: Arsenal, Manchester United, West Ham
- No user accounts or authentication
- iOS only
- No boyfriend connection feature (planned for future)
- No live match updates (future consideration)
- Off-season: the app goes quiet when there's no news — no filler content
- Notification permission is requested once; if denied, the Home Screen feed is still available but no re-prompting

## 9.1 Privacy & Data Handling

- **Device tokens** (APNs identifiers) are stored server-side to deliver push notifications. These are considered personal data under GDPR/UK-GDPR.
- **Team selection** is sent to the server to filter content. Stored alongside the device token.
- **No user accounts, emails, names, or personal information** are collected.
- **TelemetryDeck** is used for anonymised usage analytics (GDPR-compliant, no personal data).
- **"Delete My Data"** button in Settings allows users to remove their device token and team preference from the server at any time.
- A GDPR-compliant **privacy policy** is hosted at a public URL and linked from the App Store listing and the app's Settings screen.
- See BUILD_PLAN.md Step 5.3 for full privacy policy text and implementation details.

## 10. Future Roadmap

**v1.1 — World Cup 2026 (fast-follow):**
- Nation selection (32 WC nations, multiple selection)
- Tournament tracker / bracket visualisation
- WC-specific notification types (knockout, penalty, everyone's talking about this)
- Penalty survival guide (static content)
- "Everyone's talking about this" feed for neutral matches
- Tone shift from quarter finals onwards
- Post-tournament transition prompt: "Want to keep following [his name's] PL team?"

**v1.2+:**
- Expand to all 20 Premier League teams
- Social media data sources (Instagram, X)
- Post-match summaries
- Android version
- Tier 3 as premium upsell
- Live match commentary / updates

## 11. Design Direction

**Direction:** Cool older sister with sass. Warm, confident, modern. The name GoalDigger does the attitude work and the design complements rather than competes.

**The rule:** If it looks like it belongs on ESPN, Sky Sports, or FotMob — it's wrong. If it looks like it belongs next to Headspace and Pinterest on her home screen — it's right.

- **Color palette:** Rose and Dusk (active). Deep Mauve (#2D1B2E) background, Hot Rose (#E8397D) buttons/highlights, Soft Blush (#FAF0F4) cards, Warm White (#F5F0F0) text, Gold (#E8C547) for Tier 3 moments. See BUILD_PLAN.md Step 3.1 for full palette.
- **Typography:** Plus Jakarta Sans or similar rounded modern font. Headlines bold and tight. Never thin, never delicate.
- **Layout:** Card-based feed with generous whitespace and rounded corners. The pink shows up everywhere, even quietly, through borders, icons, toggles, and underlines.
- **Team theming:** Minimal — the app stays brand-neutral. Team identity comes through in content, not UI colors.
- **Overall vibe:** If someone looked over her shoulder, it should look like a cute, premium, well-designed app — not a football stats tracker.

## 12. Tone of Voice

The character: a best friend who happens to know football. Never condescending, never boring, always on her side. Wit first, warmth underneath. When the information truly matters, drop the jokes and just be straight with her.

**Core principles:**
- Make her feel clever, not tutored
- Acknowledge the absurdity of football when it's earned
- When the information actually matters, drop the jokes and just be useful
- Always end with something she can actually do or say
- Use her name and his name wherever possible to keep it personal

**Writing rules:**
- Write like a text message, not an article
- Short sentences. Full stop. Move on.
- Contractions always. "he'll" not "he will"
- Never use: Additionally, Furthermore, Moreover, It's worth noting
- Commas over semicolons. No em dashes.
- If it sounds like it was written by an AI, rewrite it

## 13. Monetisation

- **WC 2026:** One-time $10 purchase via App Store
- **Post-WC:** Premier League as follow-up product (possibly separate one-time purchase or low-cost annual subscription — TBD)
- **No monthly subscriptions.** Subscription fatigue is real and App Store handles all payments.
- API calls are per team not per user, so cost scales cleanly.
- Tier 3 "The one he brags about" is a natural premium upsell hook post-WC.
