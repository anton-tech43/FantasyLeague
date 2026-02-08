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

### 3.2 Daily News Updates

The app sends a daily push notification summarizing anything relevant happening in the Premier League world related to the user's chosen team. This includes transfers, injuries, off-pitch drama, manager quotes, and trending stories. The tone should be casual, fun, and easy to understand—not dry sports journalism.

### 3.3 Game Day Talking Points

On match days, the user receives an additional push notification with short, digestible talking points about the upcoming game. This could include recent form, key players to watch, head-to-head stats, and conversation starters like "Did you know...?" facts.

### 3.4 Tap-Through Detail View

When the user taps a notification, they land on a detail screen with more context, deeper talking points, and background info. This is for users who want to go a level deeper before the conversation.

## 4. Notification Strategy

| Type                    | Frequency         | Timing                   |
|-------------------------|-------------------|--------------------------|
| Daily news update       | Once per day      | Morning (e.g., 9:00 AM)  |
| Game day talking points | Once per game day | 3–4 hours before kickoff |

Notifications should be short and punchy (1–2 sentences max), with a "tap for more" experience.

## 5. Data Sources

The app pulls data from multiple sources to create engaging, well-rounded updates:

- **Official APIs** — Football data APIs (e.g., football-data.org, API-Football) for fixtures, scores, standings, and player stats.
- **News sites** — AI reads and summarizes articles from major football news outlets (e.g., BBC Sport, Sky Sports, The Athletic).
- **Social media** — Team Instagram accounts, player accounts, and football influencers for trending stories and off-pitch content.

An AI layer processes and summarizes all incoming data into short, engaging, girlfriend-friendly language.

## 6. User Flow

1. Download the app from the App Store.
2. **Onboarding** — Welcome screen explaining the concept. No account creation needed.
3. **Team Selection** — Pick one team (Arsenal, Man United, or West Ham).
4. **Enable Notifications** — Prompt to allow push notifications.
5. **Home Screen** — Shows latest updates and upcoming match info for the selected team.
6. **Receive Notifications** — Daily updates + game day talking points arrive via push.
7. **Tap Notification** — Opens detail view with more talking points and context.

## 7. Technical Architecture

### 7.1 Frontend

- **Platform:** iOS (Swift / SwiftUI)
- **Local storage:** UserDefaults or CoreData for team selection and preferences

### 7.2 Backend

- **Server:** Cloud-based backend (e.g., Firebase, AWS, or Supabase)
- **AI Processing:** An AI agent scrapes/reads data sources, summarizes content, and generates talking points
- **Push Notifications:** Apple Push Notification Service (APNs) via the backend
- **Scheduled Jobs:** Cron jobs or cloud functions to trigger daily updates and game-day notifications

### 7.3 Data Pipeline

1. Scheduled job runs daily (and on game days) to pull data from APIs and news sources
2. AI processes raw data into short summaries and talking points
3. Content is stored in the database
4. Push notifications are sent to users based on their selected team
5. Users tap through to see the full detail view

## 8. Monetization

- **v1:** Free to download, optional one-time purchase in the App Store (price TBD)
- **Future:** Explore subscription model if content expands

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

## 11. Tone of Voice

All content should feel like a fun, helpful friend explaining football—never condescending, never overly technical. Think "gossip column meets match preview." Examples:

> "Arsenal play Tottenham tonight—it's a BIG rivalry. Ask him if he's nervous. He probably is."

> "Saka picked up a knock in training but should be fine for Saturday. If he mentions it, just say 'at least it's not serious.'"
