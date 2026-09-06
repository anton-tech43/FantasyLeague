# Tiers: what each level actually sends

**Status:** design, 2026-09-06. Supersedes the tier tables in `PRD.md` §3.2/§4 (which
describe a volume model that was never built) and the one-line description in
`ARCHITECTURE.md` §8. Nothing here is shipped yet — §6 is the build list.

---

## 0. Read this first: the numbering

Anton's brief ranked the levels top-down ("tier 1 is the maxed one, tier 3 should be
lighter"). The database ranks them bottom-up: `device_tokens.tier` is `1 = lightest,
3 = deepest`, and **10 of the 20 devices in prod are on tier 3 today**. Flipping the
meaning of the integer would silently demote every one of them.

So the integer keeps its current direction and the levels get names that carry the
ranking on their own:

| Anton's words | This doc | DB `tier` | Label in the app |
|---|---|---|---|
| "den mest maxade" | **Deep** | `3` | The one he brags about |
| "med när det kollas fotboll" | **Match-fit** | `2` | Came to impress |
| "bör vara lägre" | **Light** | `1` | Just enough to get by |

Every table below is ordered Light → Match-fit → Deep. When we talk about this out
loud, use the names, not the numbers.

---

## 1. What tiers are for

Today the tier does almost nothing. The entire server-side gate is one line:

```ts
const minTierForType = item.type === "sunday_brief" ? 2 : 1;   // notification-sender/index.ts:274
```

and the client hides three cards (`TierGating.swift`). A Light user and a Deep user get
**the same pushes**, minus one Sunday Brief. Nobody in prod has ever chosen Light —
10 devices on Match-fit, 10 on Deep, zero on Light — which is what you'd expect when the
lowest option is called "just enough to get by" and the app costs the same either way.

The rule this doc introduces:

> **Tiers gate notifications, not the app.** If she opens GoalDigger, she sees
> everything we have for her club. What the tier decides is how much of it comes to her
> lock screen without being asked.

Gating in-app content is a punishment for someone who already paid and told us she wants
less noise. Gating pushes is a service. The one exception is *actions* (quiz, group-chat
prep) which are surfaced by default at Deep and available on demand for everyone else.

---

## 2. Deep — "The one he brags about"

**The promise:** she has the thing he hasn't thought of, and she has the score before he
looks up.

**The honest limit, stated up front.** We cannot beat a well-informed partner on breaking
transfer news. He follows the same journalists we scrape, several hours earlier, and our
news routine runs twice a day off RSS feeds that are themselves downstream. Any tier
promise built on "you'll hear the transfer first" fails publicly, repeatedly, in front of
the one person she wanted to impress. Where we *can* be first, and by minutes:

- **Match events.** `match-watcher` polls every 60 seconds and pushes within seconds.
  He is watching the match, or he is checking his phone like everyone else.
- **Lineups.** Published ~an hour before kickoff. He looks at kickoff. She can have it at
  T−60 with the one name that matters flagged.
- **Derived facts.** The streak, the table consequence, the head-to-head record, the
  referee's history. He would have to look these up, and he won't.

So Deep is built on **speed where we own the clock, and depth where he can't be bothered**.

| Moment | What lands | Latency target |
|---|---|---|
| Night before / morning of a match | Pre-match dossier: opponent's danger men, our injuries, what's at stake in the table, one stat he doesn't know | 08:00 local |
| T−60 min | Lineup drop, with the notable inclusion or absence called out | within 5 min of the lineup being published |
| Kickoff | It's started, plus the one thing to watch | < 60 s |
| Every goal | Scorer, minute, score, and what it changes | < 60 s |
| Red card, penalty, VAR overturn | Same | < 60 s |
| Half-time | The brief: what's actually happening, not the score | < 3 min of the whistle |
| Full-time | The verdict, his likely mood, and **three lines she can send** | < 5 min |
| Daily, non-match days | One insider item — a stat, an anecdote, an oddity | 08:00 |
| A rival's result changes his team's position | Rival watch push | < 5 min of that match ending |
| Sunday | The brief | 09:00 |
| Saturday | The quiz | with the matchday content |
| Always | Live Activity on the lock screen for the whole match | live |

Volume on a two-match week: **25–40 pushes**. That is the tier. Someone who chose "I want
to know everything" is not spammed by knowing everything; she is spammed by being told
things that don't matter. The quality bar, not the count, is what protects this tier.

**What makes it "more than him", concretely.** Every Deep push carries something he
doesn't have: the goal push carries the table consequence, not just the score; the lineup
push carries why the change matters; the full-time push carries the sendable line. If a
Deep push could have been written by reading the BBC score bar, it should not have been
sent.

---

## 3. Match-fit — "Came to impress"

**The promise:** she is in the conversation the whole way through the match, and she is
never the last to know something that matters.

This is roughly today's level plus the match moment, which today is missing entirely for
club followers until this week's fix.

| Moment | What lands |
|---|---|
| Match morning | Heads-up: who, when, what's at stake |
| Kickoff | It's started |
| Half-time | The brief |
| Full-time | Result, his mood, one talking point |
| News that matters | Significant news only — a signing, a sacking, an injury to someone he cares about. Not squad-rotation chatter. |
| Sunday | The brief |
| In-app | Everything: insider card, player dossiers, team page, everyone-talking |

Volume: **8–12 pushes/week**. No goal-by-goal (she's watching, or she'll get the result),
no lineup drop, no daily insider, no quiz push.

The "slightly above today" that Anton asked for is the half-time brief and the *filtered*
news. Today Match-fit gets every news item the routine publishes, whatever its weight;
that is why the August feed reads like a wire service.

---

## 4. Light — "Just enough to get by"

**The promise:** she'll know what mood he's coming home in, and she'll never be blindsided
by something big.

Deliberately lower than today.

| Moment | What lands |
|---|---|
| Match morning | Heads-up: he's got a game, here's the one line |
| Full-time | Result and mood |
| Something big | Manager sacked, star player sold, serious injury, trophy, relegation. Nothing else. |

Volume: **3–5 pushes/week.** No kickoff, no half-time, no Sunday brief, no ordinary news.

Everything else is still in the app when she opens it — including the Sunday Brief card,
which today disappears from a Light user's feed for no reason anyone can defend.

---

## 5. The matrix

`P` = pushed · `A` = in the app, not pushed · `—` = not available

| Surface | Light | Match-fit | Deep | Exists today? |
|---|---|---|---|---|
| Match-day heads-up (morning) | P | P | P | yes (`morning-push`, `matchday-reminder`) |
| Kickoff | — | P | P | yes (`match-watcher`, ungated) |
| Goal / red / penalty | A | A | P | yes (`match-watcher`, ungated) |
| Half-time brief | A | P | P | yes (`live_match_briefs`, 261 rows) |
| Full-time result + mood | P | P | P | yes |
| Full-time sendable lines | A | A | P | **no — "group chat prep" declared in `TierGating.swift`, never built** |
| Live Activity | A | A | P | yes (2.1.1, club support ships in build 10) |
| Lineup drop T−60 | — | — | P | **no — trigger removed 18 May, `starting_xi` has 0 rows** |
| Pre-match dossier | — | A | P | partly — the parts live in `team_pages` |
| News: big | P | P | P | yes, but **unranked** — see §6.1 |
| News: ordinary | — | P | P | yes |
| News: minor | A | A | P | yes |
| Daily insider item | A | A | P | rows yes (4 508), push path **no** |
| Sunday brief | A | P | P | yes |
| Saturday quiz | A | A | P | yes (304 rows) |
| Player dossiers | A | A | A | yes (136 rows) |
| Rival watch | — | A | P | WC only (`WC_RIVAL_RESULT`); **no PL equivalent** |
| Team page, everyone-talking | A | A | A | yes |

---

## 6. What has to be built

Ordered so each step unlocks the next. Sizes are honest: S = an afternoon, M = a day or
two, L = more.

### 6.1 News significance — the keystone (M)

Light and Match-fit both depend on being able to say "big news only" or "news that
matters", and **we currently cannot rank a news item at all**. Every row in
`content_items` is equally important to the pipeline.

- Migration: `content_items.significance smallint` — `2` = big (sacking, major signing,
  serious injury, trophy, relegation), `1` = ordinary, `0` = minor.
- `PROMPT.md` / `PROMPT_WC.md` emit it; `post_news.sh` validates it and refuses `2`
  without a matching event class, the same way it already refuses a non-PL club in a
  results clause.
- Backfill is not needed — the archive cron clears the feed in 7 days.

Without this, Light is just Match-fit with the Sunday Brief removed, which is the mistake
we're already living with.

### 6.2 A real push matrix in `notification-sender` (S)

Replace the ternary at `index.ts:274` with a table keyed on `(type, significance,
consequence_type)` returning a minimum tier. One function, one unit test per row.

### 6.3 Tier-aware live pushes in `match-watcher` (M)

`sendPlayingTeamPush` currently sends kickoff/goal/HT/FT to every follower regardless of
tier — which is correct for full-time and wrong for goals. The recipient query already
selects the token rows; add `tier` to the select and filter per label:
kickoff ≥ 2, goal ≥ 3, HT ≥ 2, FT ≥ 1.

This is the single highest-value change in the list: it is what makes Deep feel different
from Match-fit during the ninety minutes that the whole product is about.

### 6.4 Lineup drop at T−60 (M)

Rebuild the trigger removed on 18 May. The pattern is written down in the code comment at
`match-watcher/index.ts:479-485`: env-driven URL/token, trigger label `STARTING_XI`, fire
window kickoff−65 min, branch the fire loop. Migrations 046/047 are still in place. The
routine (`gd-starting-xi`) needs re-enabling and its prompt needs the grounding rules the
other prompts got this week.

Also: delete or restore the dead `.startingXi` branch in `FeedView.applyTierFilter` and
`ContentItem` — it has been filtering a type that has never had a single row.

### 6.5 Daily insider push for Deep (S)

4 508 insider items exist and the only way to see one is to open the team page and scroll.
Pick the freshest unseen one per followed club, push at 08:00 to tier 3. No generation
cost — the rows are already paid for.

### 6.6 Group chat prep (M)

The feature `TierGating.swift` has promised since V1 and nobody built. Definition: at
full time, three lines she can copy and send — one for if they won, one for if they lost,
one that works either way. It rides on the article the matchday routine already writes,
so it is a prompt and a schema field, not a new pipeline.

This is the most on-brief feature in the list: it is the difference between knowing more
than him and *being seen to* know more than him.

### 6.7 Pre-match dossier for Deep (M)

Assembly, not generation: opponent's `ones_to_know` from their own team page (the trick
from Lesson 94), our injuries from the `/injuries` feed, the stakes from
`team_season_state`, one insider item. Fires the morning of a match at tier 3.

### 6.8 PL rival watch (M)

`WC_RIVAL_RESULT` exists for countries. The club equivalent needs a definition of "rival"
that isn't just the derby: for a title race it's the top four, for a relegation fight it's
the bottom five. `team_context.flags` already carries `title_race` / `relegation` /
`cl_spot`, so the selection rule has an input.

### 6.9 iOS (S)

- `TierGating.swift`: stop hiding in-app surfaces. The only remaining client-side gate is
  which cards are *promoted* on the feed, not which exist.
- `TierSelectionView`: the labels stay, but each needs a concrete second line — "about 4
  a week", "about 10 a week", "everything, as it happens". Today the descriptions promise
  depth and deliver frequency.
- Settings: show what the current tier actually sends, and let her change it without
  re-onboarding.

---

## 7. What this fixes, measured

| Today | After |
|---|---|
| Tier changes 1 notification type out of 12 | Tier changes 9 of 18 surfaces |
| 0 users on Light | Light is a real product for someone who wants the mood, not the match |
| Deep is Match-fit plus a quiz | Deep is 25–40 informed pushes vs 8–12 |
| Every news item weighs the same | Three weights, and Light only ever sees the top one |
| 4 508 insider rows, 0 pushes | The depth we already generate reaches the tier that asked for it |
| "Group chat prep" promised in code since V1 | Built |

---

## 8. The quality gate comes first

`audit/2026-09/WC_CONTENT_REVIEW.md` reviews every card the World Cup shipped. The
relevant number for this document: **5 % of cards broke no house rule, 22 % had no
substantive failure, and Sunday Brief managed 0 of 148.**

Deep sends 25–40 pushes a week. At today's hit rate that multiplies weak cards rather than
strong ones, and the Deep promise — *she has the thing he hasn't thought of* — is exactly
what a templated "Ask him what they need from their next game" breaks. **Ship §6.1 and the
validator work in that review before you ship the volume in §2.**

The review also sharpens what Deep should carry. The best content in the World Cup corpus
was not information, it was what to do with the moment — "He'll need a moment. Then a hug."
That is what §6.6 group-chat prep should be built around: not more facts, better delivery.

## 9. Open questions for Anton

1. **Deep volume.** 25–40 pushes a week is a lot of lock screen. I think it is right for
   someone who picked "the one he brags about", and wrong for anyone else — which is
   exactly why the tier exists. Say if you want a ceiling.
2. **Light and news.** I've drawn "big news only" as roughly 1–2 a week. If that reads as
   too quiet to justify the price, the alternative is a weekly digest instead of nothing.
3. **Group chat prep tone.** Three lines she can send is the feature. Whether they are
   funny, informed, or both is a voice decision I'd rather you made than I did.
