# PUSH_RULES.md — what is allowed to buzz her phone, and why

**Read this before adding, widening or un-pausing any notification.**

A push is the only thing in this product that takes her attention without being
asked for. Everything else waits until she opens the app. That asymmetry is the
whole reason this page exists as its own file instead of a paragraph somewhere:
the rules were correct but spread across five files in two repositories, and
nobody could see the shape of them at once.

> **The default is silence.** A push has to earn its place against a specific
> moment in her evening. "It is interesting" is not that moment.

Same pattern as `BACKFILL_RULES.md`: one dangerous subject, one page, pointed at
from `CLAUDE.md`. **`./scripts/verify-push-rules.sh` fails if the code and this
page drift apart**, so this is a contract rather than a description — see §6.

---

## 1. Everything that can reach a lock screen

| The moment | What decides | Who gets it | Why it may interrupt her |
|---|---|---|---|
| **A goal** | `match-watcher` → `_shared/goal-push-copy.ts` | **every tier, every competition** | The one push nobody is gated out of. It is the most time-critical fact in the product and the least ambiguous. One short fact from where the goal leaves her team (ahead, level, behind), the scorer and minute first. Title and body carry her club and its score first ("Arsenal 1-0 Liverpool" at Anfield), never "1-1 to Liverpool"; same for half time and full time (2026-11-01). |
| **Kickoff** | `match-watcher` → `_shared/push-tiers.ts` | **tier 2+**, and not in early cup rounds | She can see he is watching, so it tells her less than a goal does. A second-round League Cup tie at Lincoln is not an occasion, and a push claiming it is teaches her to ignore the next one. Semi-finals and finals go to everyone. |
| **Half time** | `match-watcher` → `_shared/push-tiers.ts` | **tier 2+** | The clearest purpose of any push here. During play he is not listening and afterwards the moment is gone; half time is a fifteen-minute window and it closes. Ends with a line she can actually use. |
| **Extra time** | `match-watcher` → `_shared/push-tiers.ts` | **every tier**, every round | A one-off cup tie level after 90 (2026-10-29). It lands when she expects the full-time push and tells her the evening runs another half hour. Sent only on the feed's own `ET`, seen on two polls at the same level score and before 100', so it is never a guess from the competition's rules: the League Cup goes straight to penalties and gets nothing here. Not sent when the shootout starts either; the Live Activity shows it kick by kick and the result push follows minutes later. |
| **Full time** | `match-watcher` → `_shared/push-tiers.ts` | **every tier** | How it ended is the single fact that most shapes the next few hours in her house. Worth an interruption whether or not she has paid. Deep also gets where it leaves them in the league ("Up to 4th."), only when no other league game is still being played. A level cup tie the feed calls finished is held until it says PEN or AET (polled up to 14 hours, mig 145); a result that settles after 23:30 London or five hours after kickoff corrects the cards and does not push (`resultStillNews`). |
| **A news card** | `post_news.sh` (~60 guards) → `notification-sender` | significance 2: every tier; anything else: tier 2+ | The only route from the model to a lock screen, and the narrowest. Light gets only the big story (2026-11-01). Six separate reasons downgrade a card to feed-only (§3); most cards never push at all. The bold title must carry the fact (a name or number the story states), or `post_news.sh` sends it back. At most one per club per three hours on any one phone (`notification-sender`, counted from APNs-accepted sends, per tier: after a tier-2+ push, the club's big story still reaches Light phones, and only them), and nothing from 21:00 UTC until 07:00 London: a card written 06:00–07:00 London is held and the 07:15 sweep sends it. |
| **A tournament card** | same path, a `tournament` feed (`champions_league`, `europa_league`, `conference_league`, `fa_cup`) | **tier 2+** | Goes to every device, so it has to be the knockout night itself, not another club's news. Anton, 2026-11-01: Match-fit and Deep only. **The `league_cup` feed never pushes**; it is read in the feed. |
| **The Monday brief** (type `sunday_brief`) | same path as a news card | **tier 2+** | The one piece that sets up her week rather than reacting to something: the weekend that was and the week ahead, Monday 08:00 London (`gd-sunday-brief`, moved from Sunday 2026-11-01). A Monday-night game is called "tonight". |
| **Kickoff time** | `matchday-reminder`, hourly 07:00–19:00 UTC | every tier, **every round of every cup** | The useful fact is not *that* there is a match but *when*, which is only meaningful in her own time zone. Rendered per phone from `device_tokens.timezone`, never once centrally; the title uses the club's short name. **This is the one pre-game push per match**: a tap opens Matchday › Before. The first run sends; later runs retry only today's fixtures with no row in `matchday_reminders_sent`, until an hour before kickoff (mig 152). It replaced `morning-push`, the 08:00 fallback, and the day-before push, whose code and cron were removed 2026-11-01. |
| **The Live Activity appearing** | `match-watcher` push-to-start at the first live tick | every follower with Live Activities on | Not a separate banner: the alert in a push-to-start is what lights the activity up on the lock screen. It is the feature she turned on, so it is not tier-gated. Ended at full time, or by `la-end-sweep` (mig 135/138) if that end fails. Behind `LA_CHANNELS` (mig 157/158) iOS 18+ phones start on a broadcast channel instead of a per-activity token: one per side of the fixture (home followers, away followers, neutral for both or neither), chosen by the token's `team_ids`; same start alert, and the updates and end go out as one broadcast per channel with the same priority and no alert, so nothing new buzzes. **The live take** (docs/LIVE_TAKES_PLAN.md phase 1, 2026-11-03) is the `note` line under the score at ~30', half-time and ~70': a **silent update**, decided in code (`_shared/match-take.ts`, `_shared/la-notes.ts`), never an alert, sent only to followers of the side it is about (a device following both sides or neither gets none). A note change alone goes at priority 5; a goal or the change to HT clears it, and the end never carries one. |
| **A Live Activity channel test** | `la-channel-test`, called by hand from SQL | **one named phone** (a push-to-start token prefix) | Not for her. Starts a fake Arsenal v Liverpool card on Anton's phone to learn whether shipped builds accept a channel start (docs/LIVE_ACTIVITY_PLAN.md, "Channel test procedure"). No cron, no fan-out. |
| **The lineups** | `match-watcher` → `_shared/lineup-notable.ts` | **nobody — DRY RUN**, behind `LINEUP_PUSH_ENABLED` (off) | Built 2026-10-27, logs the line it would say (a regular of substance out, an outsider starting, ≥ 5 changes; never full-backs) to `pipeline_health` stage `starting_xi_fire`, target `lineup:<fixture>`, and keeps it in `fixture_lineups.note` (mig 151). With the secret set to `1` the line **replaces the T−30 kickoff body** for whoever gets that push; it never adds a push. Anton reads real cases first. |
| **A consequence card** (title won, relegated, a place clinched) | `match-watcher` writes it | **nobody — feed only** | 2026-11-01 (LOCK-02-12): the sender skips any row with a `consequence_type`. Where her own club's result leaves it in the table rides on the full-time push instead, for Deep only. |
| **A crash / backend alarm** | `client-error-alert` | a developer phone (`dev_alert_devices`) | Not for her at all. Called by `notification-sender` on an APNs auth failure, and by `check_pipeline_heartbeat()` (every 5 minutes), which since 2026-11-01 includes a live match whose feed has not moved for 8 minutes (mig 153). No model, nothing to do by hand. `dev_alert_devices` was empty until 2026-10-25 — every alarm before then reached nobody. |

Tier names are in `TIERS.md`: `1 = Light`, `2 = Match-fit`, `3 = Deep`. The
integer direction is load-bearing — flipping it silently demotes every device in
production.

### What is NOT in this table

There is no model anywhere in a push path. Every line above is either
deterministic code or a card that already passed the guard ladder before it was
allowed near this list.

---

## 2. Published, and deliberately never announced

The interesting half. Each line is a decision that silence serves her better.

| What | Why it never pushes |
|---|---|
| **The full-time article** (`gd-matchday`) | `match-watcher` pushed the result seconds after the whistle. The article is what she opens *from* that push, not a second interruption about the same event. Two alerts for one event is how people turn notifications off. |
| **Small facts** (`gd-insider`) | It exists to make the app worth opening on a quiet day. Pushing it turns a nice surprise into a daily demand on her attention. |
| **The weekend quiz** (`gd-saturday-quiz`) | An invitation to play is a request, not news. |
| **Player cards** (`gd-player-dossier`) | Reference material. Nobody wants to be told reference material was updated. |
| **The club page** (`gd-team-page`) | An alert saying a page changed is an alert about our own maintenance. |
| **The live brief** (`gd-live-brief`) | The app polls it while the match is on. She is already watching. |
| **A follow-up to a story already on her feed** (`post_news.sh` same-story update, 2026-10-29) | The card is rewritten in place and moves to the top of the feed instead of a second card arriving (three Kane cards in a row was the evidence). A story pushes at most once: if the first card pushed, the update is silent and `pushed_at` stays; if it never pushed, the update may push only by passing every downgrade in §3, and otherwise gets `push_eligible=false` so the hourly sweep cannot find the fresh `published_at`. The test is `same_story()` in `goaldigger-routines/fact_checks.py`. |

For the last five of these the absence is structural, not configured: those
routines have **no push path at all**. That is the strongest available form of
"this must not push" — not a rule that could be flipped, an absence of wiring.

---

## 3. The six downgrades

A card passes every correctness guard, is published to the feed, and still does
not push. These are product judgements, not correctness ones, and every one was
added after a real complaint or a real audit. All six live in `post_news.sh`
and set `push_eligible=false` before the insert.

| Reason (the literal `force_reason`) | Added because |
|---|---|
| `non-football celebrity reaction` | 2026-05-22: Lewis Hamilton crying at Arsenal, and Prince William drinking with Villa players, both pushed. The prompt-level rule was read and ignored, so it is enforced in the script. |
| `international duty written for a PL club` | Broadened 2026-06-05 after Maguire, Salah, Foden, Palmer, Kulusevski and Son all leaked as pushes on their *club* feed. |
| `speculative transfer/manager rumour` | 2026-05-28, an Arsenal user on three rumour pushes in 36 hours: "Nobody cares. Nothing of value here." Confirmed signings still push. |
| `opaque-teaser headline` | A push that conveys a reaction without the news — "it's already written" — is bait without the payload. |
| `quiet hours (21:00–05:59 UTC, PL clubs)` | The 00:30 run produced 32% of August's PL pushes between 23:37 and 00:03 London, against a store listing that promises "we don't send at 3am". **A downgrade, not a queue:** a delayed push arrives detached from what caused it. The one exception is the last stretch of the morning: a card written between 06:00 UTC and 07:00 London (the 06:30 UTC run, in winter) is held, and the hourly sweep sends it at 07:15 London (2026-11-01). |
| `matchday article (FT push already sent by match-watcher)` | See §2. |


---

## 4. Where each decision actually lives

Five files, and nothing else may send a push to her (plus a test harness that reaches one named phone).

| File | Decides |
|---|---|
| `backend/supabase/functions/match-watcher/index.ts` | The five live-match pushes. |
| `backend/supabase/functions/_shared/push-tiers.ts` | Which tier and which cup rounds get the framing pushes. A goal bypasses it. |
| `backend/supabase/functions/notification-sender/index.ts` | The single gate for everything written. Claims before sending, one push per club per three hours per tier (`notification-sender/throttle.ts`), quiet hours, tier filter, skips consequence cards and the League Cup feed, pages past 1,000 rows. |
| `backend/supabase/functions/matchday-reminder/index.ts` | The one scheduled push. |
| `backend/supabase/functions/la-channel-test/index.ts` | Nothing for her: a hand-run Live Activity test that reaches one named phone. |
| `goaldigger-routines/post_news.sh` | The six downgrades in §3, the fact-in-the-title check, and the morning hold. |

`_shared/apns-client.ts` is the only way to reach APNs, so **"can this file send a
push?" is answerable with one grep**, and §6 does exactly that.

---

## 5. Adding a new push

1. **Name the moment.** Not the content — the moment in her evening it lands in.
   If you cannot write that sentence, there is no push here.
2. **Compare it to a goal.** A goal is time-critical and unambiguous. Almost
   nothing else is, which is why almost everything else is gated or silent.
3. **Default it to feed-only** and let evidence argue it up. Every entry in §3 is
   a push that shipped first and was walked back after a complaint.
4. **Decide the tier in code, not in a prompt.** Lesson 77: a soft rule in a
   prompt was read and ignored on its first live fire.
5. **Add the row to §1 and run `./scripts/verify-push-rules.sh`.** It will fail
   until this page knows about your sender.
6. **Run `./scripts/verify-push-eligible.sh` after the next news fire** — any
   `push_eligible=false` item with a `pushed_at` or an `apns_send` row is a
   violation of the contract in §2.

---

## 6. The check that keeps this page honest

```bash
./scripts/verify-push-rules.sh
```

Eighteen root documents in this repo are marked historical because they stopped
matching the code and nothing noticed. This one is checked:

- every Edge function importing `_shared/apns-client.ts` is named in §4
- every `force_reason` string in `post_news.sh` appears verbatim in §3
- the tier floor for each live event in `push-tiers.ts` matches §1
- `notification-sender`'s tier floors (Monday brief, tournament, news by significance) match §1

If you add a sender, widen a tier or invent a downgrade, the script fails and
names the line. Update this page in the same change — same rule
`MAINTENANCE.md` §5 already applies to `DATA_SOURCES.md`.

_Written 2026-10-08, revised the same day when the dead World-Championship pause was deleted, from `ARCHITECTURE.md` §5, `TIERS.md`, `push-tiers.ts`,
`notification-sender/index.ts` and `post_news.sh`. The shape is Model 4 of the
system map._
