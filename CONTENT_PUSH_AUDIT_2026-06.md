# Content + Push Audit — 2026-06-05

Full audit of GoalDigger's editorial output: **PL news (last 7d, 77 items)**, **WC news (all, 195)**, and **every push sent in the last 30 days (577 items)**, scored on five axes — **relevant · timing · quality/voice · true · prompt-fix**.

Method: a deterministic truth layer (the `content-audit` linter — standings claims, $0, no LLM) plus 10 in-session evaluation agents (one per team-group) grading each push against the live PROMPT.md rules. No paid cross-team Edge/routine loop was used.

---

## Headline result

The system is **voice-competent and, where it matters most, truthful** — but it **massively over-pushes**, especially unconfirmed transfer speculation and international call-ups, with certain emotional openers. Roughly **a third of the 30-day pushes carried at least one flag.** This matches every running complaint ("SHIT speculations", "Nobody cares about our third striker", the Odegaard/Rogers/PSG pushes).

Per-dimension flag counts (approximate; dimensions overlap):

| Dimension | ~Count / 577 | Nature |
|---|---|---|
| Not relevant | ~93 | Speculation, int'l call-ups, pundit/off-pitch noise pushed |
| Weakly relevant | ~70 | Tangential / think-piece / other-club drama |
| Bad timing | ~68 | Night pushes, repeats, predictions-as-fact |
| Poor quality/voice | ~65 | Banned register, opener repetition, reused titles |
| "Untrue" (agent-flagged) | ~10 | **Mostly false alarms — see truth caveat below** |

## Truth — the good news (with an important caveat)

- **Deterministic standings truth: 0 contradictions** across 544 audited pushes (relegation / champions / safety / qualification). The one real error of that class — West Ham's "stay up" — was already fixed.
- **⚠️ The agents' "factual" flags are unreliable where they depend on player rosters.** The LLM's training knowledge is *older* than the app's data. The clearest case: agents flagged "Semenyo scored for Man City / Man City winger Semenyo" as wrong (he was a Bournemouth player in their memory) — but **Semenyo transferred to City; the app was right and the agents were stale.** A fix applied on that basis was reverted. **Discard all agent fact-checks that hinge on which club a player is at.**
- **Reliable "untrue" signals = internal self-contradictions only**, of which a handful are real and worth your eyes:
  - **Liverpool, 5th:** the 05-31 brief says "no Champions League" while the team-page `state_line` says "in the Champions League". One is wrong — depends on this season's CL allocation (does 5th earn a spot?). **Flagged for you; not auto-fixed.**
  - Man City: points gap to Arsenal stated as "four" (05-24) then "seven" (05-31).
  - Man Utd: Carrick "confirmed" 5 days before the official announcement.
  - Chelsea: FA Cup opponent described as both semi-final and final foe.
  - Argentina: opener dated June 16 in one item, June 17 in another.

## Systemic patterns (ranked) + the fix

1. **Unconfirmed transfer/manager speculation pushed as certain.** The #1 issue, on nearly every team (City Vinicius/Gvardiol, Liverpool Diomande, Bournemouth's whole Iraola saga, Spurs Romero, Wolves Gomes…). The TRANSFER gate (PROMPT.md L685) existed but was ignored. → **`post_news.sh` speculation guard widened** ("in talks", "close to", "chasing", "shortlist", "could join", "bid rejected", manager-search phrasings) **with a confirmed-news override**. Speculation now force-downgrades to feed-only deterministically.
2. **Club-vs-country: international call-ups pushed for club feeds** with emotional openers (Odegaard, Maguire, Salah-Egypt, Foden, Palmer, Kulusevski, Son). The guard existed but searched for "World Cup" (we renamed to **"World Championship"**) and required a strict possessive. → **int'l-duty guard widened** (adds "World Championship", non-possessive mentions, call-up verbs). PL-club feeds only; WC country feeds still push their own tournament news.
3. **Near-duplicates / saga repeats within 72h** (PSG-final reminder ×5, Liverpool Chelsea-draw ×3, Forest safety ×3, Southampton spygate ×7, Chelsea Alonso-appointment ×4). The cooldown only covered status-changing events. → **PROMPT.md cooldown broadened to a SAGA/REPEAT rule**: one push per result / fixture / rumour-thread / problem-resolution pair.
4. **Voice: banned register + opener repetition.** "The plot twist at keeper", "Big drama", "Strong reaction incoming", "This just got worse"; "He'll have opinions" reused 7×/team; "Phone-his-dad moment" reused across teams. → **`post_news.sh` hard-rejects the banned register in `push_title`**; **PROMPT.md adds an opener-rotation rule** + expanded ban list.
5. **Off-pitch trivia pushed** (royalty visits, banknotes, nostalgia, obituaries, pundit takes, tactical think-pieces, Scotland's back-shaving squad diary). Relevance gate leak — softened by the prompt reinforcement; harder to catch deterministically, monitored going forward.

## Timing — investigated, mostly historical

- **47 news pushes fired 00:38–00:54 UTC (≈01:40 BST)** — but all in a **05-08 → 05-12 window with no recurrence since** (created=pushed in real time; a since-resolved schedule/manual-run artifact). No action needed unless it returns.
- **The big "same-minute bursts" were BACKFILL, not user spam.** The 05-07 18:56 cluster (23 items/11 teams) and 05-17 01:37 cluster were bulk-stamped over many hours; the 17 null-title items live in that backfill. The 05-31/05-17 10:15 clusters are the weekly sunday_brief firing one-per-team (20 different feeds). **Not reported as spam.**
- Genuine same-minute *doubles* (2 items, e.g. City 05-26 22:47) are real but minor — addressed by a notification-sender throttle if desired (see below).

## WC-specific (pre-tournament window)

- Voice and timing are clean (no night pushes; same-minute timestamps are across *different* country feeds = different users).
- **Scotland is over-pushing** (22 pushes vs 8–14 for peers), much of it off-pitch trivia → feed-only.
- One **cross-feed attribution miss**: the Saudi Arabia feed pushed a Ronaldo/Al-Nassr *club* story.
- The 06-05 batch (france/iraq/ivory_coast/mexico/spain) shipped "World Cup" in body — **by your standing call this is acceptable** ("news saying World Cup is safe enough"); not treated as a defect.

## What was changed (applied)

- **Content (DB):** West Ham relegation brief corrected earlier this session. (The Man City / Ghana "Semenyo" edits were a mistake on stale knowledge and were reverted — app data was correct.)
- **Routines repo (`41c5fd2`):** widened speculation + int'l-duty guards, new banned-register reject, opener-rotation + saga-dedup rules, sunday-brief internal-consistency rule.

## Flagged for you (no auto-fix)

- **Liverpool 5th = CL or not?** Resolve the team-page-vs-brief contradiction once you confirm this season's CL allocation.
- **Optional notification-sender code** (not prompt-fixable): skip pushes with null `push_title` (backfill insurance), and a per-team push throttle (max 1 push per ~15 min) to kill genuine same-minute doubles.
- **Push volume itself**: ~19 push-eligible items/day across all teams. The speculation/int'l/saga guards above will cut this materially; worth re-measuring in a week.
