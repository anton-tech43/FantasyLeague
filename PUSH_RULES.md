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
| **A goal** | `match-watcher` → `_shared/goal-push-copy.ts` | **every tier, every competition** | The one push nobody is gated out of. It is the most time-critical fact in the product and the least ambiguous. Copy is 40 hand-written variants, seeded so a line does not repeat. |
| **Kickoff** | `match-watcher` → `_shared/push-tiers.ts` | **tier 2+**, and not in early cup rounds | She can see he is watching, so it tells her less than a goal does. A second-round League Cup tie at Lincoln is not an occasion, and a push claiming it is teaches her to ignore the next one. Semi-finals and finals go to everyone. |
| **Half time** | `match-watcher` → `_shared/push-tiers.ts` | **tier 2+** | The clearest purpose of any push here. During play he is not listening and afterwards the moment is gone; half time is a fifteen-minute window and it closes. Ends with a line she can actually use. |
| **Full time** | `match-watcher` → `_shared/push-tiers.ts` | **every tier** | How it ended is the single fact that most shapes the next few hours in her house. Worth an interruption whether or not she has paid. |
| **A news card** | `post_news.sh` (~60 guards) → `notification-sender` | tier depends on the card | The only route from the model to a lock screen, and the narrowest. Seven separate reasons downgrade a card to feed-only (§3); most cards never push at all. |
| **The Sunday brief** | same path as a news card | **tier 2+** | The one piece that sets up her week rather than reacting to something, published at the one hour she might read something longer. |
| **Game day** | `morning-push`, 08:00 UTC | every tier **with a fixture today**, **only if the 07:00 reminder did not go** | A fallback, not a second push: it skips any fixture already in `matchday_reminders_sent`. Templated once and reused forever — no model, no cost. |
| **Kickoff time** | `matchday-reminder`, 07:00 UTC | every tier, **not in early cup rounds** | The useful fact is not *that* there is a match but *when*, which is only meaningful in her own time zone. Rendered per phone from `device_tokens.timezone`, never once centrally. **This is the one pre-game push per match**: a tap opens Matchday › Before (2026-10-27; My Turn → Pre-game until the Matchday tab merged). Early League Cup / FA Cup rounds get no reminder, the same rule as their kickoff push. |
| **Day before** | `matchday-reminder?mode=prep` | **nobody — PAUSED, and staying paused** | Anton, 2026-10-26: one push that opens Pre-game is enough, and the matchday reminder now does that. Un-pausing this would make it two. `130_*.sql.PENDING_APP_RELEASE` is not to be applied. |
| **A consequence card** (table moved, who goes through) | `match-watcher` writes it, `notification-sender`'s hourly sweep pushes it | tier depends on the card | Reaches a lock screen only through the sweep, which since 2026-10-27 applies the same rules as a news card: nothing older than 90 minutes, nothing in quiet hours (21:00–05:59 UTC). A missed one stays in the feed. |
| **The Live Activity appearing** | `match-watcher` push-to-start at the first live tick | every follower with Live Activities on | Not a separate banner: the alert in a push-to-start is what lights the activity up on the lock screen. It is the feature she turned on, so it is not tier-gated. Ended at full time, or by `la-end-sweep` (mig 135/138) if that end fails. |
| **The lineups** | `match-watcher` → `_shared/lineup-notable.ts` | **nobody — DRY RUN** | Built 2026-10-27, logs the line it would say (a regular of substance out, an outsider starting, ≥ 5 changes; never full-backs) to `pipeline_health` stage `starting_xi_fire`, target `lineup:<fixture>`. Anton reads a weekend of real cases first. When it ships it replaces the T−30 kickoff body rather than adding a push. |
| **A crash / backend alarm** | `client-error-alert` | a developer phone (`dev_alert_devices`) | Not for her at all. Called by `notification-sender` on an APNs auth failure. `dev_alert_devices` was empty until 2026-10-25 — every alarm before then reached nobody. |

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
| `quiet hours (21:00–05:59 UTC, PL clubs)` | The 00:30 run produced 32% of August's PL pushes between 23:37 and 00:03 London, against a store listing that promises "we don't send at 3am". **A downgrade, not a queue:** a delayed push arrives detached from what caused it. |
| `matchday article (FT push already sent by match-watcher)` | See §2. |


---

## 4. Where each decision actually lives

Five files, and nothing else may send a push.

| File | Decides |
|---|---|
| `backend/supabase/functions/match-watcher/index.ts` | The four live-match pushes. |
| `backend/supabase/functions/_shared/push-tiers.ts` | Which tier and which cup rounds get the framing pushes. A goal bypasses it. |
| `backend/supabase/functions/notification-sender/index.ts` | The single gate for everything written. Claims before sending, 5-minute per-team throttle, tier filter, pages past 1,000 rows. |
| `backend/supabase/functions/morning-push/index.ts`, `matchday-reminder/index.ts` | The two scheduled pushes. |
| `goaldigger-routines/post_news.sh` | The seven downgrades in §3. |

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
- `notification-sender`'s content-type tier floor matches §1

If you add a sender, widen a tier or invent a downgrade, the script fails and
names the line. Update this page in the same change — same rule
`MAINTENANCE.md` §5 already applies to `DATA_SOURCES.md`.

_Written 2026-10-08, revised the same day when the dead World-Championship pause was deleted, from `ARCHITECTURE.md` §5, `TIERS.md`, `push-tiers.ts`,
`notification-sender/index.ts` and `post_news.sh`. The shape is Model 4 of the
system map._
