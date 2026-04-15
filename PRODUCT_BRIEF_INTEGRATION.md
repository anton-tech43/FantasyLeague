# Goal Digger — Product Brief Integration Plan

**Date:** April 6, 2026
**Source:** `goaldigger-product-brief.txt` (from Product Manager, April 2026)
**Status:** DOCUMENTED — All changes from the product brief have been integrated into project docs (April 6, 2026). Security fixes also completed (see CHANGELOG_SECURITY.md).

---

## Purpose

The product brief introduces significant new features and scope changes compared to the current BUILD_PLAN.md and PRD.md. This document maps every delta between the brief and the current docs, prioritised for implementation.

**Rule:** All agents must check this document before starting work on any feature listed here.

---

## Priority 1: Changes That Affect Architecture (Must update BUILD_PLAN.md and AGENT_CONTRACTS.md before coding)

### 1.1 Personalisation — Her Name + His Name

**What's new:** Onboarding now collects her name and his name. Both are used throughout the app for personalised content.

**Impact:**
- **Database:** `device_tokens` table needs `her_name TEXT` and `his_name TEXT` columns
- **GDPR:** Names are PII. Privacy policy must be updated to disclose name collection. "Delete My Data" must also delete names.
- **Content pipeline:** `{{his_name}}` and `{{her_name}}` become prompt variables passed to Claude
- **iOS:** New onboarding screens (her name, his name), stored in UserDefaults + sent to server
- **Prompts:** All prompts need updated to use names for personalisation

**Agent tasks:**
- Backend Agent: Add columns to schema, update REST API contract
- iOS Agent: Add name entry screens to onboarding, store locally and POST to server
- Pipeline Agent: Add `{{her_name}}` and `{{his_name}}` to prompt variables

### 1.2 Content Tiers (3 levels)

**What's new:** Users self-select a tier during onboarding. Content depth and notification frequency vary by tier.

**Tiers:**
| Tier | Label | Content Depth | Max notifications/day |
|------|-------|--------------|----------------------|
| 1 | "Just enough to get by" | Minimal — match day + 1 talking point | 1 |
| 2 | "Came to impress" | Regular news + talking points through the week | 2 |
| 3 | "The one he brags about" | Everything including stats, transfers, deep analysis | 3 |

**Impact:**
- **Database:** `device_tokens` table needs `tier INTEGER DEFAULT 2 CHECK (tier IN (1, 2, 3))`
- **Content pipeline:** Claude must generate 3 versions of every story (one per tier depth)
- **Anti-spam:** Max notifications per day is now tier-dependent, not a flat number
- **iOS:** New tier selection screen in onboarding + changeable in Settings
- **Prompts:** Tier depth instructions must be added to generator prompts

**Agent tasks:**
- Backend Agent: Add tier column, update anti-spam rules, update notification-sender logic
- iOS Agent: Add tier selection screen, Settings tier change, pass tier to API
- Pipeline Agent: Update prompts to generate tier-appropriate depth

### 1.3 World Cup 2026 Mode

**What's new:** The app supports two modes: Premier League and World Cup 2026 (or both). WC mode has different onboarding (nation selection), different content types, and tournament-specific features.

**Impact:**
- **Database:** New `nations` table, new `device_token_nations` join table (many-to-many — user can follow multiple nations), new content types (`wc_group`, `wc_knockout`, `wc_penalty`, `wc_everyones_talking`)
- **Content pipeline:** New data sources for WC (API-Football covers international), new prompt templates for WC content
- **iOS:** Branched onboarding flow (PL/WC/Both), nation selection grid, tournament tracker view, bracket visualisation, penalty survival guide (static content), "everyone's talking about this" feed section
- **Anti-spam:** New notification types (WC knockout alert, WC penalty alert, WC everyone's talking about this)

**This is a MAJOR scope expansion.** Recommend building as a separate phase after PL v1 is stable.

**Agent tasks:**
- Backend Agent: New schema migration (002_wc_schema.sql), new Edge Functions or expanded existing ones
- iOS Agent: Branched onboarding, nation selection grid, tournament tracker UI, new feed sections
- Pipeline Agent: New WC-specific prompts for all content types

### 1.4 Talking Point Engine — Context Layer

**What's new:** Before generating content, the AI receives "pressure flags" about the team's current situation (title race, relegation battle, cup final, etc.). These change the emotional weight of talking points.

**Impact:**
- **Data pipeline:** `data-fetcher` must compute and store pressure flags per team per run
- **Database:** New `team_context` table or JSONB column on `teams` storing current flags
- **Prompts:** Pressure flags passed as a new variable to content generators

**Agent tasks:**
- Backend Agent: Compute flags from standings/form data, store them, pass to content generator
- Pipeline Agent: Add context layer section to prompts with flag descriptions

---

## Priority 2: Changes That Affect UI/Content Only (Can be done in parallel with Priority 1)

### 2.1 Updated Onboarding Flow (8 screens)

**Current:** Welcome → Team Selection → Notification Prompt → Feed
**New:** Welcome → Her Name → His Name → What to Follow (PL/WC/Both) → Team/Nation Selection → Tier Selection → Notifications → First Talking Point

**iOS Agent owns this entirely.** See product brief "ONBOARDING FLOW" section for exact copy and flow.

### 2.2 Updated Voice & Writing Rules

**What's new:** More specific voice guidelines, banned words list, new copy examples for every surface.

**Key additions:**
- Write like a text message, not an article
- Contractions always
- Never use: Additionally, Furthermore, Moreover, It's worth noting
- Commas over semicolons, always
- No em dashes anywhere
- Use her name and his name throughout

**Pipeline Agent must update all prompts to include these rules.**

### 2.3 Visual Identity — Color Palette

**What's new:** Two defined color palettes (Rose and Dusk as primary, Rose and Cream as backup).

**Primary palette (Rose and Dusk):**
| Role | Name | Hex | Usage |
|------|------|-----|-------|
| Primary | Hot Rose | #E8397D | Buttons, highlights, key moments |
| Background | Deep Mauve | #2D1B2E | App background |
| Cards | Soft Blush | #FAF0F4 | All content cards |
| Text | Warm White | #F5F0F0 | Text on dark backgrounds |
| Accent | Gold | #E8C547 | Tier 3 details, premium feel |

**iOS Agent must update Theme.swift** with these values. This replaces the current warm off-white palette.

### 2.4 Context Cards — His Team Page, Player Cards, Ones to Watch

**What's new:**
- His Team Page: club context written in GoalDigger voice (stadium, manager, top 3 players, rival, fun fact)
- Player Cards: tappable from any player name in feed (name, age, position in plain English, fan sentiment, current form)
- Match Day "Ones to Watch": 3 players per match with context

**Impact:**
- **Database:** May need `player_cards` table or generate on-the-fly via Claude
- **iOS:** New views for team page, player cards, ones to watch card
- **Prompts:** New prompt templates for team page content and player card content

### 2.5 Push Notification Rules — Expanded

**What's new:** More notification types, tier-based frequency limits, specific timing rules.

**New notification types vs current:**
| Type | Current | New |
|------|---------|-----|
| Match day heads-up | Yes | Yes (9am, includes player teaser) |
| Result notification | Yes | Yes (within 5-10 min of FT, any time of day) |
| Big news alert | Yes | Yes (max 1/day, Tier 2+ only) |
| Weekly summary | No | Yes (Tue/Wed, Tier 2+ only) |
| Monthly summary | No | Yes (Tier 1 only) |
| WC knockout alert | No | Yes (all tiers) |
| WC penalty alert | No | Yes (all tiers) |
| WC everyone's talking | No | Yes (Tier 2+ only) |

### 2.6 Monetisation — Updated

**What's new:**
- WC 2026: one-time $10 purchase (unchanged)
- Post-WC: PL as follow-up product (possibly separate purchase or low-cost annual subscription — TBD)
- Tier 3 as natural premium upsell hook post-WC
- "No monthly subscriptions. Subscription fatigue is real."

### 2.7 App Store Listing — Updated Copy

**What's new:** Full new App Store copy provided in the brief. Includes:
- App name: "GoalDigger - Football for Girlfriends" (30 chars)
- Subtitle: "His team. Your secret weapon." (30 chars)
- Keywords updated with WC 2026 terms
- New description copy (above/below the fold)

---

## Priority 3: Static Content (Can be authored anytime)

### 3.1 Penalty Survival Guide (WC)
Static card available throughout the tournament. What happens during a penalty shootout, what to expect from him, what to say/not say.

### 3.2 Group Stage Explainer Card (WC)
One-time dismissable card explaining how the group stage works in plain language.

### 3.3 WC Transition Prompt
After tournament ends: "Well that was something. Want to keep following [his name's] Premier League team?"

---

## Recommended Implementation Order

1. **Security fixes** — DONE (see CHANGELOG_SECURITY.md)
2. **Priority 1.1 + 1.2** (Names + Tiers) — DOCUMENTED in BUILD_PLAN.md (schema, AppState, onboarding, API contracts)
3. **Priority 1.4** (Context layer) — DOCUMENTED in BUILD_PLAN.md (team_context table), PROMPTS.md (context flags in prompts), AGENT_CONTRACTS.md (Contract 10)
4. **Priority 2.1 + 2.2 + 2.3** (Onboarding, voice, visual) — DOCUMENTED in BUILD_PLAN.md (8-screen onboarding, Rose and Dusk palette, writing rules)
5. **Priority 2.4 + 2.5** (Context cards, notifications) — DOCUMENTED in BUILD_PLAN.md (player_cards, team_pages tables, new endpoints), PROMPTS.md (team page + player card + ones to watch generators), PRD.md (notification tier matrix)
6. **Priority 1.3** (World Cup 2026) — DEFERRED to fast-follow. PL ships first. Tracked in PRD.md Section 10.
7. **Priority 3** (Static content) — DEFERRED to WC phase.

**Key decisions made (April 6, 2026):**
- Names stored LOCAL-ONLY (not server-side) — simpler GDPR
- Color palette: Rose and Dusk (dark theme)
- 3 agents (Backend, iOS, Pipeline) — no change
- PL first, WC fast-follow

---

## What's NOT Changing (Confirmed Same)

- Tech stack (Supabase, Claude, APNs, SwiftUI)
- API-Football as data source
- 3 PL teams in v1 (Arsenal, Man Utd, West Ham)
- $10 one-time purchase model
- No user accounts or authentication
- iOS only
- Content generated per team, not per user
- TelemetryDeck for analytics

---

*This document should be updated as each priority item is implemented. Mark items as DONE with the date and agent who completed them.*
