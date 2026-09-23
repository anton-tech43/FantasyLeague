# Called it — the build contract

Anton, 2026-09-23: she picks two or three lines before kick-off, and the app tells her when the
moment came. **The app never asks whether she said it.** It knows what happened; that is enough.
Delivery rides the goal push that already goes out — no new notification.

This file fixes the shapes so the three workstreams cannot drift. Read it before touching
anything below.

## What is actually resolvable

Only moments that already push can resolve, because the push is the delivery. That is kickoff,
every goal, half-time and full-time. Within those, the feed gives us:

| Trigger | Fields we can read |
|---|---|
| `goal` | which side, scorer name, scorer's `players.position`, penalty, own goal, minute |
| `halftime` | ahead / level / behind, whether we have conceded |
| `fulltime` | win / draw / loss, clean sheet, comeback from behind at half-time |

**Not resolvable, do not write lines about it:** which foot, headers, corners, crosses,
possession, chances, anything about how a goal was built. API-Football's event `detail` is only
`Normal Goal | Penalty | Own Goal | Missed Penalty`. A line whose trigger is not in the table
above cannot ship.

That is roughly a dozen distinct moments. It is enough for a slip of three, and it is the ceiling.

## The three bands, and the rule that keeps the game alive

A round of three that all miss is the failure mode that kills this feature. So an offer is always
**one banker, one likely, one longshot**:

- `banker` — happens in the large majority of matches (someone scores; it is level at some point)
- `likely` — happens often enough to be worth picking
- `longshot` — a penalty, an own goal, a late winner. This is the fun one.

The offer function refuses to return a slip without a banker.

## Contract 1: content, in `lingo.json` under `calls`

```json
{
  "id": "opp-forward-scores",
  "line": "We have given him far too much space there.",
  "trigger": { "kind": "goal", "side": "them", "scorerRole": "Attacker" },
  "band": "longshot",
  "when": ["any", "opp-set-piece"],
  "termId": "space"
}
```

`side`: `us | them | any`. `scorerRole`: `Goalkeeper | Defender | Midfielder | Attacker | any`
— the four values `players.position` actually holds, per the `PlayerSlots` refusal to invent a
fifth. Optional `penalty`, `ownGoal` booleans and `minuteFrom` / `minuteTo`. `halftime` takes
`state: ahead|level|behind` and optional `conceded: 0`; `fulltime` takes `state: win|draw|loss`
and optional `cleanSheet` / `comeback`.

`when` uses the Overheard tag vocabulary unchanged, so a slip is fixture-aware for free: against
a set-piece side the offer can reach for set-piece lines.

`termId` is optional and links the call back to a Lingo term she has met, which is the whole
point — the words she learned are the words she gets to use.

## Contract 2: device to server

Writes go through a SECURITY DEFINER RPC, never a table upsert — anon has no access to
`device_tokens` (SEC-1/2, migration 071). New RPC, same shape as `register_device_token`:

```sql
save_match_calls(p_apns_token text, p_fixture_id bigint, p_picks jsonb)
```

Stored on a new `device_tokens.match_calls jsonb` column, **not a new table**, so
`delete-my-data` keeps working untouched — the row it already deletes is the row the picks live
on.

**The stored pick carries its own text**, `{ id, line, trigger }`, not just an id. The content
bundle ships in the binary and the server has no copy of it; the server must not need one.

## Contract 3: resolution and the push line

`_shared/match-calls.ts`, pure and tested:

```ts
export function matchedCalls(stored: unknown, fixtureId: number, outcome: Outcome): CallPick[]
export function appendCallLine(body: string, pick: CallPick): string
```

Wired into `sendPlayingTeamPush`'s per-device loop in `match-watcher`, immediately after
`const body = args.copy.bodies[country]`. Add `match_calls` to that function's `device_tokens`
select. A stale fixture id resolves to nothing.

**Her line replaces the flavour line, it does not sit after it.** The push body has a 90-character
budget and the random pool line already spends most of it. When a pick lands, the pool line is the
least valuable text in the body and her own called line is the most valuable, so the pool line is
what goes. The scorer lead stays, because it names the player. The rendered-worst-case measurement
stays as a backstop and should now never fire.

That is what caps a call line at **60 characters**, not a stylistic preference: it is what is left
of the budget once the scorer lead is paid for.

Scorer position comes from a `players` lookup by `playerApiId`, which `enrichPhotos` already
performs. Extend that one query; do not add a second.

`sendPlayingTeamPush` takes `outcomeByTeam` keyed by playing-team slug, the same shape
`copy.bodies` already has, **not** one shared `Outcome`. `state` mirrors between the two sides but
`conceded`, `cleanSheet` and `comeback` do not, so a single outcome cannot be flipped per device.

Three cases resolve to nothing on purpose: a tick where both sides scored (no single side, scorer
or minute, so nothing can be said honestly), a stale fixture id, and a goal whose scorer the feed
has not yet published. When two picks land on one event only the first is named; the body has room
for one line.

## Contract 4: the app

`LingoCall` on `MyTurnContent`, every field `decodeIfPresent` — all My Turn state is one
UserDefaults blob and an old build must survive a new key.

`LingoCalls.offer(context:) -> [LingoCall]` is pure: `MatchContext` in, three calls out, seeded by
`fixtureKey` so a paused slip never reshuffles. `MyTurnStore` gains
`matchCalls { fixtureId, pickedIds, pickedAt }`.

After the match the app resolves locally against the fixture's stored events rather than waiting
for a push it may never have received. That means the trigger logic exists in Deno and in Swift.
**Both read the same test vectors** from `tools/myturn/call_vectors.json`, so the two cannot
disagree without a test going red.

## What is out of scope

Substitutions, bookings and VAR, because no push carries them. Asking her to confirm she said it.
Any line about how a goal was built. A leaderboard, a streak, or a reminder to come back — the
store header rule stands: she did not choose this hobby.

## What the feed cannot say, and what it would cost to fix

The content pass cut ten kinds of line. Every casualty was the feed, not the voice. Ranked by
what I would pay for them:

1. **A keeper howler.** No event carries a mistake. The best living-room line in the deck and it
   cannot ship at any price.
2. **Red cards, ten men, substitutions.** The events exist in `/fixtures/events`. No push carries
   them, and the push is the delivery. Fixable only by sending a notification we have decided not
   to send.
3. **A brace or a hat-trick.** Needs a running per-scorer tally across the match; the goal push
   knows one scorer and no history.
4. **Shot quality, placement, how the goal was built.** `detail` is `Normal Goal | Penalty | Own
   Goal` and nothing else. This is the one the matchup card most tempts you into, because
   `opp-set-piece` and `opp-aerial` are live tags with no event-level counterpart.
5. **A goalless first half.** `halftime` carries ahead / level / behind and `conceded`, but not
   whether *we* have scored, so "nil-nil at half-time" is inexpressible. `level` plus
   `conceded: 0` is close and is not the same thing.
6. **A margin.** `fulltime` carries win / draw / loss and clean sheet, no goal difference, so
   nothing can fire on the four-nil the moment it happens.

**5 and 6 are the cheap ones**, and they are the next thing to do: a `scored` field on the
half-time outcome and a `goalDifference` on full-time. Both numbers are already inside the payload
match-watcher polls every minute, so neither costs an API call. Deferred only because three agents
were holding this contract open at the time.
