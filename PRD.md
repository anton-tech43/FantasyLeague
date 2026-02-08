# Goal Digger — Product Requirements Document (PRD)

**Version:** 1.0
**Date:** February 8, 2026
**Author:** [Your Name]

---

## 1. Overview

Goal Digger is an iOS app designed for girlfriends (or anyone) who want to connect better with their football-loving partners by staying informed about Premier League news, match days, and talking points—without needing to be a football fan themselves.

The app delivers short, engaging push notifications with daily updates and game-day talking points, so the user always has something relevant to say.

## 2. Target User

The primary user is someone (stereotypically a girlfriend) with little to no interest in football, whose partner is a passionate Premier League fan. She wants to feel connected and be able to engage in football conversations naturally.

## 3. Core Features

### 3.1 Team Selection

On first launch, the user selects one Premier League team to follow. In v1, the available teams are Arsenal, Manchester United, and West Ham.

### 3.2 News Updates (When Newsworthy)

The app sends a push notification when something genuinely newsworthy happens related to the user's chosen team. This includes transfers, injuries, off-pitch drama, manager quotes, and trending stories. If nothing meaningful is happening, no notification is sent — the app should never spam the user. The tone should be casual, fun, and easy to understand—not dry sports journalism.

### 3.3 Game Day Talking Points

On match days, the user receives an additional push notification with short, digestible talking points about the upcoming game. This could include recent form, key players to watch, head-to-head stats, and conversation starters like "Did you know...?" facts.

### 3.4 Home Screen Feed

The Home Screen serves as the central notification feed — a scrollable timeline of all updates for the user's selected team. This means users can dismiss push notifications when the timing is bad and catch up later in the app. The feed gives a quick overview of everything the user needs to know.

### 3.5 Tap-Through Detail View

When the user taps an item in the feed (or a push notification), they land on a detail screen with more context, deeper talking points, and background info. This is for users who want to go a level deeper before the conversation.

## 4. Notification Strategy

| Type                    | Frequency                  | Timing                                    |
|-------------------------|----------------------------|-------------------------------------------|
| News update             | Only when newsworthy       | When relevant news breaks (never at night) |
| Game day talking points | Once per game day          | Close to kickoff                           |

Notifications should be short and punchy (1–2 sentences max), with a "tap for more" experience. Notifications are never sent during nighttime hours. News updates are timed to when the story breaks rather than on a fixed schedule. Game day notifications are sent close to the match to keep the information fresh and top of mind.

## 5. Data Sources

The app pulls data from multiple sources to create engaging, well-rounded updates:

- **Official APIs** — Football data APIs (e.g., football-data.org, API-Football) for fixtures, scores, standings, and player stats.
- **News sites** — AI reads and summarizes articles from major football news outlets (e.g., BBC Sport, Sky Sports, The Athletic).
- **Social media** — Team Instagram accounts, player accounts, and football influencers for trending stories and off-pitch content.

The Claude API (Anthropic) processes and summarizes all incoming data into short, engaging, girlfriend-friendly language.

## 6. User Flow

1. Download the app from the App Store.
2. **Onboarding** — Welcome screen explaining the concept. No account creation needed.
3. **Team Selection** — Pick one team (Arsenal, Man United, or West Ham).
4. **Enable Notifications** — Prompt to allow push notifications.
5. **Home Screen** — A feed of all updates and upcoming match info for the selected team. Users can scroll through and catch up at their own pace.
6. **Receive Notifications** — Daily updates + game day talking points arrive via push.
7. **Tap Notification** — Opens detail view with more talking points and context.

## 7. Technical Architecture

### 7.1 Frontend

- **Platform:** iOS (Swift / SwiftUI)
- **Local storage:** UserDefaults or CoreData for team selection and preferences

### 7.2 Backend

- **Server:** Cloud-based backend (e.g., Firebase, AWS, or Supabase)
- **AI Processing:** Claude API (Anthropic) processes and summarizes content from data sources into engaging talking points
- **Push Notifications:** Apple Push Notification Service (APNs) via the backend
- **Scheduled Jobs:** Cron jobs or cloud functions to trigger daily updates and game-day notifications

### 7.3 Data Pipeline

Data is fetched **per team**, not per user. In v1 with 3 teams, this keeps API and AI costs flat regardless of user count.

1. Scheduled jobs pull data from APIs and news sources for each of the 3 teams
2. Claude API processes raw data into short summaries and talking points
3. Content is stored in the database, tagged by team
4. Push notifications are sent to users based on their selected team
5. Users tap through to see the full detail view

## 8. Monetization

- **v1:** Paid app — $10 on the App Store (one-time purchase, no in-app purchases)
- **Future:** Explore subscription model if content expands (e.g., more teams, live updates)

## 9. Scope & Limitations (v1)

- Only 3 teams available: Arsenal, Manchester United, West Ham
- No user accounts or authentication
- iOS only
- No boyfriend connection feature (planned for future)
- No live match updates (future consideration)

## 10. Future Roadmap

- Expand to all 20 Premier League teams
- Add boyfriend's team connection (follow two teams)
- Android version
- Live match commentary / updates
- Post-match summaries ("Here's what happened")
- Customizable notification frequency

## 11. Design Direction

Goal Digger should look and feel like a modern lifestyle app — not a sports app. The target audience has no interest in football, so the design should feel welcoming, clean, and something they'd happily keep on their home screen.

- **Aesthetic:** Light, warm, and modern. Think lifestyle/social app, not ESPN.
- **Color palette:** Soft, muted tones — no aggressive reds, dark backgrounds, or neon accents. Neutral base with subtle accent colors.
- **Typography:** Friendly, rounded sans-serif. Easy to read, never blocky or bold in a "sports" way.
- **Layout:** Card-based feed with generous whitespace and rounded corners. Should feel closer to Instagram stories than a news ticker.
- **Team theming:** Minimal — the app stays brand-neutral regardless of which team is selected. Team identity comes through in content, not UI colors.
- **Icons & imagery:** Simple, illustrative style. Avoid stock football imagery or crest-heavy designs.
- **Overall vibe:** If someone looked over her shoulder, it should look like a cute, well-designed app — not a football stats tracker.

## 12. Tone of Voice

All content should feel like a fun, helpful friend explaining football—never condescending, never overly technical. Think "gossip column meets match preview." Examples:

> "Arsenal play Tottenham tonight—it's a BIG rivalry. Ask him if he's nervous. He probably is."

> "Saka picked up a knock in training but should be fine for Saturday. If he mentions it, just say 'at least it's not serious.'"
