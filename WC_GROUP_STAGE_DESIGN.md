# WC Group-Stage Context + Stakes-Aware Pushes — Design

**Status:** design (approved direction; not yet built)
**Date:** 2026-06-09 · WC kicks off June 11
**Scope rule:** **server-side only for now — no iOS build.** The native "group hub" screen is deferred to a later submission (no kickoff pressure; do it right).

---

## 1. The problem

The WC group stage flips the product from "his team" to "**his group**." A follower needs to understand, for his country:
- where his team sits — points, placement — and where the **other three** group teams sit;
- **what his team needs** in each remaining game;
- **how important** each game is (and when a game is a dead rubber);
- when a **rival's result** changes his team's situation.

And pushes must match the **stakes**: don't fire energetic "must-win" pushes for a game with nothing riding on it — and never use the wrong *emotional register* (a dead rubber because they're **out** is not "enjoy it stress-free").

## 2. Decisions captured (from the planning thread)

| # | Decision |
|---|---|
| A | **App-first, server-side-first.** Ship everything we can through existing server-driven cards (no build). Native group hub = later submission. |
| B | **Top-2 math = computed as certainty.** Clean points math. |
| C | **3rd-place = soft only.** Never asserted as a guarantee — cross-group, settles late. Phrase as "still alive, could sneak through as a best third, depends on other groups." |
| D | **Stakes value carries a *reason*, not just a level:** `decisive / can_improve_seeding / qualified_already / eliminated`. Qualified and eliminated are both "low stakes" but emotionally inverted. |
| E | **Tone follows the reason.** eliminated → muted/respectful, never "enjoy it." Volume drops when eliminated. |
| F | **Rival-result pushes = informational, not prescriptive.** State the fact ("Senegal beat Croatia in [his team]'s group"). Do **not** compute "your team now needs X" in the push — that derived claim depends on a refreshed table + tiebreakers and is where wrong pushes are made. Implications live in-app. Same WC group only; on the **game result**, not per goal. |
| G | **PL → feed-only** during the WC (`push_eligible=false` / pause PL routines' push path). PL still in feed; WC pushes full. |
| H | **Deterministic population.** Stakes text is templated by our own engine and written via **SQL or a free routine** — **never** by looping the paid `team-page-generator` Claude pass across 48 countries (CLAUDE.md hard rule). |

## 3. Architecture

### 3.1 Stakes engine (new, pure, deterministic)
A pure function (mirrors `_shared/detect-consequences.ts` + `consequence-templates.ts`). Input: a WC group's full state (all 4 teams' points + each team's remaining fixtures) from `raw_fetch_logs.api_football_standings` (WC `league_id = 1`, per-group arrays). For a given team, output **per upcoming fixture**:

```
{
  stakes_level: "decisive" | "can_improve_seeding" | "qualified_already" | "eliminated",
  reason: short machine reason,
  certainty: "certain" | "soft",          // certain = top-2 points math; soft = 3rd-place-dependent
  what_at_stake: templated statement,       // "Win and they top the group"
  importance_dots: 1..5
}
```

**Math rules:**
- **Top-2 (certain):** standard min/max points reachability — same shape as the existing consequence detector. Produces guarantees ("draw and they're through", "must win or out").
- **3rd-place (soft):** if a team can only advance via the best-third route, mark `certainty: "soft"` and never state a guarantee. Best-third is cross-group (12 groups → 8 best thirds, ranked points→GD→goals across all of them) and only resolves late — out of scope to compute precisely. Surface as "in contention, undecided."
- **Dead-rubber detection:** if the team is already guaranteed a final placement (through OR out) regardless of this game → `qualified_already` or `eliminated`.

### 3.2 Tone mapping (drives push existence + voice)
| stakes_level | push? | register |
|---|---|---|
| decisive | yes | energetic, high-stakes |
| can_improve_seeding | yes (mild) | "matters for seeding, not survival" |
| qualified_already | maybe / calm | positive — "job done, free hit, he can relax" |
| eliminated | **feed-only or one quiet note** | muted, respectful — **never** "enjoy it"; a dignified sign-off |

### 3.3 Rival-result pushes (informational)
- **Trigger:** full-time of the *other* fixture in his WC group (`match-watcher` already detects FT; the score is known immediately, independent of the standings refresh).
- **Content:** factual only — *"Senegal beat Croatia in [his team]'s group."* Optional neutral framing, **no** "what they need" math.
- **Why factual:** the result is verifiable at FT; the derived stake needs a refreshed table + tiebreakers and can be wrong if pushed immediately. Implications appear in-app once the table/stakes recompute (hedged where soft).
- Naturally low volume: ≤1 "other game" per round until the simultaneous final matchday.

## 4. Surfaces — what ships with NO build (existing server-driven cards)

The team page renders `team_pages.content` JSONB across **Info / Calendar / Table** tabs. These fields are already drawn by the live app:

| Need | Card / field (server-driven, no build) |
|---|---|
| Live group table (his team + other 3, points, placement, GD) | **`standings`** card (Table tab) — rank/W-D-L/GF/GA/GD/points + `competition_label` "Group A". Highlights his row. Keep fresh from `api_football_standings` (deterministic merge, no LLM). |
| How important each game is | **`upcoming_fixtures[].importance_dots`** (1–5) (Calendar tab). Dead rubber → 1, decisive → 5. |
| What they need (short) | **`upcoming_fixtures[].importance_label`** (≤30-char statement) — "Win and they top the group" / "Must win or out". |
| Game context + the other teams | **`next_fixture.preview`** (long free text) + **`this_week.text`** ("what's happening in the group this week"). |
| What a result means (with tone) | **`post_match`** (state win/loss/draw + text + talking_point + `expires_at`). |
| Group mood / position | **`mood`**, **`form`** (position) as support. |

**Population:** the stakes engine writes `importance_dots`/`importance_label`/`preview`/`this_week`/`post_match` deterministically into `team_pages.content` via SQL or a free routine (NOT the paid generator). The `standings` entries refresh from the raw fetch logs.

## 5. What needs a build (deferred — native group hub)
- Per-row **qualification badges/colours** on the standings table (a "Q / E / alive" column).
- A **designed combined group screen** (table + per-game scenarios + rival results in one place).
- **Rival-result** as a dedicated UI element (interim: rival context goes into `next_fixture.preview` / `this_week`).
- `importance_label` longer than ~30 chars.

→ Build carefully, submit when ready. No kickoff dependency.

## 6. PL wind-down
- Flip PL `content_items` to `push_eligible=false` and/or pause the PL routines' push path (`gd-news` PL + PL matchday). WC routines stay hot. PL remains visible in-feed. Reversible.

## 7. Sequence (server-side, no build)
1. **Stakes engine** (pure module + unit tests against fixture data — top-2 certain, 3rd-place soft, dead-rubber + reason).
2. **Templates** for `what_at_stake` / importance_label / preview / this_week (deterministic, GoalDigger voice).
3. **Wire into pushes**: stakes_level + reason gate push existence + tone; integrate with `notification-sender` / the consequence path.
4. **Rival-result pushes** (informational) off the match-watcher FT hook, same-group only.
5. **Card population**: write stakes fields into `team_pages.content` + keep `standings` fresh (SQL / free routine).
6. **PL feed-only** flip.
7. Later: **native group hub** build + submit.

## 8. Out of scope / open
- Precise best-third (3rd-place) qualification math — soft-only for now.
- Native group hub UI — deferred (Section 5).
- Knockout-stage stakes — separate (group stage first).

## 9. Verification
- Stakes engine unit tests: synthetic groups → assert certain top-2 statements, soft 3rd-place, correct dead-rubber + reason (qualified vs eliminated).
- Truth check: no `importance_label`/push ever asserts a guarantee the math can't back (esp. 3rd-place).
- Rival push: fires once at FT of the other group game, factual text only, same group only, not per goal.
- Eliminated team: no energetic push; tone is muted; volume drops.
- Cards render in the live app with no build (standings live table + stakes labels visible).
- PL: no PL pushes fire; PL still appears in feed.
