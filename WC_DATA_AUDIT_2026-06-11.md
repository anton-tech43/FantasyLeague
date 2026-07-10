# World Cup data-correctness audit — 2026-06-11 (tournament kickoff)

Whole-application fact-check of all 48 WC country pages against reality on the day the tournament kicked off: managers, players, fixtures/dates, and squad completeness. Plus a reusable freshness lens so staleness is easy to spot going forward.

**Method.** In-session, free (no paid `callClaude()` Edge loop — honours the CLAUDE.md hard rule). DB inventory via SQL + 12 parallel web-verification agents (one per group, 4 countries each) + a 13th to source replacements for absent players. Every correction is web-sourced (June 2026), not model memory — the whole point, since the API-Football feed and any single model are both stale on discretely-changing facts (transfers, sackings).

**Scope checked:** 48 managers · 144 players (48×3) · 12 groups + 144 group fixtures · per-card freshness.

---

## Headline results

| Dimension | Result |
|---|---|
| **Managers** | **48/48 correct.** All 12 hardcoded `COACH_OVERRIDES` vindicated (see below). Only edit: Qatar name completed `Lopetegui` → `Julen Lopetegui`. |
| **Group composition** | **12/12 groups + every matchup correct.** |
| **Fixture dates** | **Correct.** The "off-by-one-day" flags were host-local-vs-UTC rendering, NOT data errors (stored kickoff instants are right; iOS renders device-local). |
| **Fixture *card*** | **1 code bug found + fixed** — non-WC fixtures were leaking into `upcoming_fixtures` (all 48). |
| **Players — present** | **4 not in their final squad** (cut/injured) → replaced with verified squad members. |
| **Players — accuracy** | **~41 one-liner corrections** across 33 countries (stale club, wrong age, wrong record). |
| **Freshness** | Tool shipped (`v_wc_page_freshness` + `get_wc_freshness()` + `scripts/wc-freshness.sh`). All 48 pages currently fresh. |

---

## 1. Managers — the "suspects" were all real recent changes

Six managers looked wrong from training-era memory. Every one turned out **correct** in the DB — they are real hirings/firings from Mar–May 2026 that a model would "correct" back to a stale answer. This is the strongest possible vindication of the verify-don't-assume rule:

- **Morocco — Mohamed Ouahbi** ✓ (Regragui resigned 6 Mar 2026 after the AFCON final; Ouahbi promoted).
- **Ghana — Carlos Queiroz** ✓ (Otto Addo sacked 31 Mar 2026; Queiroz in).
- **Tunisia — Sabri Lamouchi** ✓ (replaced Sami Trabelsi early 2026).
- **Saudi Arabia — Georgios Donis** ✓ (Hervé Renard sacked ~17 Apr 2026; Donis appointed 24 Apr).
- **Uruguay — Marcelo Bielsa** ✓ (survived sack pressure; leaves only after the tournament).
- **Curaçao — Dick Advocaat** ✓ (returned 11 May 2026).

Only change applied: **Qatar `Lopetegui` → `Julen Lopetegui`** (full name).

## 2. Fixtures — dates are correct; a code bug was leaking non-WC games

**Dates: not errors.** Agents flagged many openers as "a day later than Wikipedia." That is the UTC-vs-host-local gap: an evening kickoff in the Americas crosses midnight UTC (e.g. USA–Paraguay 18:00 PT Jun 12 = `01:00 UTC Jun 13`; Sweden–Tunisia evening-Mexico Jun 14 = `02:00 UTC Jun 15`). The stored value is the true kickoff *instant*; iOS converts to the user's device timezone, so each user sees the right local date. **No date was changed.**

**🔴 Code bug fixed — non-WC fixtures leaked into `upcoming_fixtures` (all 48 teams).** `updateWcDynamicFields` ingested `api_football_fixtures_next` without filtering by competition. A country's payload also carries its *post-tournament* games (England's live feed = 3 World Cup fixtures + 6 UEFA Nations League). Those Sep–Nov 2026 games surfaced as upcoming; most as 2-dot "Warm-up game", but any whose opponent name collided with a real group rival (England vs Croatia in Oct + Nov) were mislabeled **"Group stage game" with 4 importance dots**. Teams that showed only 3 were merely lucky API-Football had no post-Nov fixtures for them.

**Fix:** filter parsed fixtures to `league.id === 1` (the WC). New pure helper `filterFixturesByLeague` in `_shared/fixture-rollover.ts` (+ unit test), wired into `parseUpcomingFixtures(..., WC_LEAGUE_ID)`. Future-proofs the knockouts (also league 1). **Result post-deploy: all 48 teams now show exactly their 3 group games**, no warm-ups, no mislabels. `next_fixture` unchanged (already correct).

## 3. Players — 4 absences + ~41 corrections

### 3a. Not in the final squad → replaced (the worst class: a "key player" who isn't even there)
| Country | Removed (reason) | Replaced with (club) |
|---|---|---|
| Morocco | Youssef En-Nesyri (omitted) | **Ayoub El Kaabi** (Olympiacos) |
| Japan | Kaoru Mitoma (hamstring, out) | **Daichi Kamada** (Crystal Palace) |
| England | Cole Palmer (cut by Tuchel 22 May; Foden too) | **Bukayo Saka** (Arsenal) |
| Jordan | Yazan Al Naimat (ACL, out) | **Ali Olwan** (Al-Sailiya) |

### 3b. Stale clubs explicitly named in one-liners (factually wrong as of June 2026)
Son Heung-Min `Tottenham→LAFC` · McTominay `Man Utd→Napoli` · Ben Doak `Liverpool→Bournemouth` · Kudus `West Ham→Tottenham` · Partey `Arsenal→Villarreal` · Semenyo `Bournemouth→Man City` · Xhaka `Leverkusen→Sunderland` · Akanji `Man City→Inter (loan)` · Embolo `Monaco→Rennes` · Kessié `Barcelona→Al-Ahli` · Hincapié `Leverkusen→Arsenal` · Achouri `Celtic→FC Copenhagen` · Taremi `Inter→Olympiacos` · Saud Abdulhamid `Roma→Lens` · Aït-Nouri `Wolves→Man City` · Alaba `Real Madrid→(free agent)` · Luis Díaz `Liverpool→Bayern` · Wissa `Brentford→Newcastle` · Irankunda `Bayern→Watford` · Almirón `Newcastle→Atlanta Utd` · Enciso `Brighton→Strasbourg` · Sanabria `Serie A→Italy (Serie B)` · Juninho Bacuna `Championship→Volendam` · Chong `PL→Sheffield Utd` · Stamenić `Sparta Prague→Swansea` · Cacace `Empoli→Wrexham` · Álvarez `West Ham (on loan 25/26)` · Al-Hamadi `Championship→England (Luton, L1)` · Jackson `Chelsea→Bayern (loan)`.

### 3c. Wrong age / role / record
Mokoena 28→29 · Lee Kang-In 24→25 · Džeko 39→40 · Pierrot 30→31 · Mejbri 22→23 · Doku 23→24 · Openda 25→26 · Arnautović 36→37 · Ronaldo 40→41 · Souček (no longer Czech captain) · Cyle Larin (not all-time top scorer — Jonathan David is now) · Romo (DM/CB, not box-to-box) · Schick / Uzbekistan Gʻaniyev (unverified "number 10" removed). Plus 2 pre-existing **em-dashes** (Egypt) cleaned to commas.

**All player edits are durable** — `dynamic_only` preserves `ones_to_know.players`, and no full-regen cron exists. The post-deploy refresh also propagated corrections into opponents' "Coming up" blocks (e.g. Sweden's Tunisia block now shows Achouri at Copenhagen).

## 4. Freshness tracking (the "easy to follow in future" ask)

- **Migration 061** — `v_wc_page_freshness` (per-page + per-card `updated_at` and ages) + service-role `get_wc_freshness(stale_hours=14)` RPC. Two tiers: **dynamic** cards (standings / next_fixture / form — ~2h SLA by day) vs **static/LLM** cards (manager / ones_to_know / season — days old is normal). `stale` trips only when a page misses a full waking cycle (>14h), so the overnight 22:00–06:00 UTC fetch gap doesn't false-positive.
- **`scripts/wc-freshness.sh [stale_hours]`** — prints the dashboard (mirrors `scripts/insights.sh`).
- Current state: **48 pages, 0 stale.** The tool also surfaces that the LLM cards (non-override managers, season) were last fully regenerated 2026-05-18 — visible, expected, not stale.

---

## What was NOT changed (and why)
- **Fixture dates** — correct UTC instants (host-local rendering explained above).
- **`COACH_OVERRIDES`** — all 12 verified correct; only Qatar's name completed.
- **Cape Verde players** — agents flagged stale clubs, but the one-liners name no club, so nothing to correct.
- **Past-tense "former X" references** (Pépé "former Arsenal man", Wan-Bissaka "former Man Utd") — accurate as written.
- **No correction pushes to users** — feed/page edits only (irreversible, user-facing).

## Deploy / verification trail
- Code: `_shared/fixture-rollover.ts` (`filterFixturesByLeague` + test, 6/6 pass), `team-page-generator` (`parseUpcomingFixtures` league filter, `WC_LEAGUE_ID`) — deployed.
- DB: migration 061 applied; ~47 SQL field-edits committed; all 48 refreshed `dynamic_only` (48 ok / 0 fail).
- Verified: upcoming_fixtures = 3/team across all 48; replacements + overrides + edits survived refresh; opponent blocks propagated; 0 em-dashes; freshness dashboard green.
