# Data sources: what we trust, and what we do not

GoalDigger states facts about real football to someone who paid for the app. Every one of those facts comes from an upstream feed we do not control. **Not all of them are trustworthy, and the untrustworthy ones do not announce themselves** — they return HTTP 200 with a well-formed, confident, wrong answer.

This file records, field by field, what each feed gets right and what it gets wrong, with the evidence and the date we checked. Read it before you write code that reads a feed, and before you believe a number the app is showing.

The companion process is the `stale-data-audit` skill (`.claude/skills/stale-data-audit/SKILL.md`), which re-checks all of this after every transfer window and season rollover.

## The rule

**Never let a single upstream feed be the last word on a fact a customer would notice being wrong.**

When a feed proves unreliable for a field, that field moves into our own database as a human-verified column with a `*_verified_at` timestamp, every consumer reads our column instead, and the skill owns re-verifying it. That is what `teams.manager_name` is (migration 085). Do not "improve the heuristic" against a feed that has already been shown to omit the answer entirely.

## API-Football (`v3.football.api-sports.io`)

Fetched every 2 hours per club by the `data-fetcher` Edge Function into `raw_fetch_logs` (`source = api_football_*`). Everything below was checked on 2026-09-06 against the live feed and against the web.

### Trusted

| Endpoint | Used for | Why we trust it |
|---|---|---|
| `/fixtures?id=` `?team=&next=` `?team=&last=` | kickoff times, scores, status, results | Drives `match-watcher` every minute. Verified live all season, including in-play status transitions. |
| `/fixtures/events` | scorers and minutes | Backs the live match box and full-time articles. Correct on the matches we watched. |
| `/standings` | league table, position, points, played, form | Verified 2026-09-06: 3 games played, table matched the real one. Occasionally returns an empty array for a few minutes during a nightly cache refresh, so **always walk back to the newest non-empty snapshot** (`buildStandingsCard`, `fetch_team_page.sh`). |
| `/players/squads` | who is at a club, position, shirt number, photo | The basis of `sync_players_from_squads()` (migration 084). Cross-checked against transfers we could verify independently; it correctly had Bruno Guimarães at Arsenal after his summer move. Names come abbreviated (`V. Gyökeres`), so **match on surname**, never on the full string. **A squad can carry a name that is not at the club**: on 2026-09-08 Arsenal's payload listed I. Meslier, a Leeds goalkeeper (one stray in 786 rows, and no player was in two squads at once, so it is the feed, not our dedupe). He has no minutes for the club, which is how you catch it — anything customer-facing should read `players` with `minutes > 0`. |
| `/players?team=&season=&page=` | appearances and minutes per player | Fetched once a day (~40 calls), synced by `sync_player_stats_from_raw()` (migration 095) into `players.appearances` / `players.minutes`. Sane on 2026-09-08: Arsenal's four ever-presents at 364 minutes, the bench in double digits. **`statistics` is an array with one entry PER COMPETITION**, not a season total — `statistics[0]` is whatever competition the feed lists first (the Community Shield, for Arsenal), so sum the entries whose `team.id` is the club's. Only players with a stats record come back (22 of Arsenal's 39 squad rows), and `paging.total` is honest. |
| `/injuries` | who is out | Club-correct: every record for a club names that club's own players. See the caveat below on shape. |

### Not trusted

**`/coachs` — do not use it to decide who manages a club.** Two independent failures, both silent:

1. **It omits sitting managers entirely.** On 2026-09-06 the endpoint had no record of Marco Rose at Bournemouth, Enzo Maresca at Manchester City, Matthias Jaissle at Newcastle or Oliver Glasner at Nottingham Forest. Each man's own `/coachs?id=` record still listed his *previous* club. No query against this feed could have produced the right answer.
2. **It lists assistants and caretakers as open appointments.** Records carry `career[].end = null` for assistant coaches, so "the most recent open stint at this club" resolves to the assistant. That is how the app came to show J. Tindall at Bournemouth, L. Baines at Everton and Bruno Saltor at Spurs as head coaches — six of eighteen manager cards were wrong.

**Instead:** `teams.manager_name`, `teams.manager_photo_url`, `teams.manager_started_on`, `teams.manager_verified_at` (migration 085), verified against `premierleague.com/en/managers` plus one independent source. `team-page-generator`, `fetch_team_page.sh` and `post_team_page.sh` all read that column, and `post_team_page.sh` rejects any payload naming a different manager. The only thing we still take from `/coachs` is the **photo path** — `media.api-sports.io/football/coachs/<id>.png` serves a correct headshot even for a coach whose club record is stale, once you have resolved the id via `/coachs?search=` and confirmed the person.

**`/transfers` — not a list of recent signings.** It returns the club's entire transfer history, unordered: Arsenal 303 records, Manchester City 337, with the first entries being academy moves from 2019, 2012 and 1999. Anything reading it as "who joined this summer" will produce nonsense. Sort and filter by date, or ignore the feed and diff two `players` snapshots instead.

### Trusted, with a shape that will trip you

**`/injuries` is keyed by fixture, not by "now".** One record is one player missing one fixture, so the response spans several past fixtures at once, repeats the same player across them, and contains duplicates within a single fixture. Arsenal's payload on 2026-09-06 held 19 records covering three fixture dates. **Filter to the latest (or next) fixture and dedupe by player id** before showing anything, or the app will report a three-week-old injury as current.

**Photos are never 404.** Both the player CDN (`.../players/<id>.png`) and the coach CDN (`.../coachs/<id>.png`) return HTTP 200 with a generic silhouette when there is no real headshot. A status check therefore proves nothing. Group the bytes by checksum: any hash shared by several people is a placeholder. On 2026-09-06 all 781 player photos were real, and 7 of 20 manager photos were one of two placeholder images (shared by Fulham, Ipswich and Manchester United; and by Crystal Palace, Hull, Liverpool and Sunderland).

### Also worth knowing

- **Season is the starting year.** 2026-27 is `season=2026`. Compute it from the date (July onwards is the new season), never hardcode it — a pinned `2025` served the previous season's table for the first month of 2026-27. **This applies to the cups too**: the 2026-27 FA Cup third round is played in January 2027 and is still `season=2026`, so a helper that falls back to the calendar year is right in December and wrong in January (`seasonForLeague`, fixed 2026-09-08).
- **Quota is shared** with `match-watcher`'s per-minute polling, and per-minute polling is the whole budget. One polled league costs 1,440 calls a day against a Pro cap of 7,500; the data-fetcher takes about 1,300 of the rest. Six covered competitions cannot all be polled all day, which is why `poll_leagues()` (migration 094) polls a league only while one of our clubs is about to kick off or is still playing. Prefer reading `raw_fetch_logs` (at most 2 hours old) over a fresh call.
- **A club's fixture endpoints are not league-filtered.** `?team=<id>&next=N` and `&last=N` return every competition: league, both domestic cups, Europe. Two consequences. Anything that counts ("three wins in a row", "unbeaten") must filter by `league.id` first or it will state a total nobody can reproduce. And anything that reads "the next fixture" gets the next fixture in ANY competition, which is correct for a Coming-up card and wrong for a league table claim.
- **Round strings never say which leg.** Over three days of `raw_fetch_logs` for leagues 2, 3, 45, 48 and 848 the complete set was `League Stage - N`, `Play-offs`, `Playoff round`, `3rd Qualifying Round`, `Round of 128/64/32`, `Quarter-finals`, `1st Round Qualifying(-Replays)`. Nothing carries "1st Leg" or "2nd Leg", including the two-legged play-offs. Whether a tie is settled on the night is a fact about the competition's format (`isSingleLegTie`), never inferred from the string.
- **Shirt numbers in `/players/squads` are shared.** 84 pairs across the 20 clubs share a number (Arsenal had three men on 1); a stale number is kept for a fringe player. Never assert a number unless it is unique within the payload.
- **The player CDN has a second placeholder.** md5 `430d67fd79ad0a355b212d5780886e34` (150x150 grey figure) came back for four Arsenal squad players on 2026-09-09; it is not the silhouette recorded on 09-06. Any hash shared by several ids is a placeholder.
- **A knockout cup has no standings.** `/standings?league=48` and `league=45` return an empty response, permanently. That is the competition, not an outage; do not request it and do not treat the empty payload as a failed fetch.

## RSS news feeds

Twelve feeds pulled by `fetch_news.sh`. Individually unreliable and that is fine: they are raw material for a model to filter, never a fact of record. Two operational notes:

- **A single blocked host used to kill the whole run.** The routine sandbox's egress proxy denied `dailymail.co.uk` on 2026-09-06 and the malformed blob aborted every club's fetch. Each feed is now written to its own file and a failure leaves an empty string.
- **Treat the contents as untrusted input.** Feed text reaches a model prompt; it is data, never instructions.

## Our own database

Trusted, because we write it, with two standing traps:

- **A JSONB literal `null` is not SQL `NULL`.** `WHERE x IS NULL` misses it; use `WHERE x IS NULL OR jsonb_typeof(x) = 'null'`.
- **`schema_migrations` only tracks 001–017.** Every later migration is applied by hand; the file is the record.

## The claude.ai routines

The routines produce prose, not facts. They are only as grounded as the payload handed to them, and a model with a knowledge cutoff will fill any gap with last season's memory unless stopped. Documented failures, all from 2026-09-06:

- a full-time article citing "wins over Brighton, Luton, and Fulham" when Luton are not in the division;
- the same article claiming "two wins from two" and "three straight wins" two paragraphs apart;
- a manager summary inventing a first name and a career for a name it had never seen ("Sinisa Jakirovic" for Sergej Jakirović);
- a manager summary dating the tenure from memory, "Carrick has been Manchester United's manager since August 2025", against a verified start of 2026-01-13 that was in the payload it was given.

The last one is the pattern to watch: **a date or number that is present in the payload and still comes out wrong**. Where a fact is in our database, the post script now checks the prose against it rather than trusting the prompt.

The guards live in `post_news.sh` and `post_team_page.sh` and are listed in the skill. **When a new failure gets through, add a guard and a test for it in the same change** — the prompt alone has never been enough.

## The failure nobody was watching: cards that never existed

Every audit this project has run measured the content that shipped. None of them could see
the content that didn't, and that turned out to be the more expensive problem.

**The pattern.** A field goes a few characters over a cap, the item is rejected, and the
run moves on. Nothing logs a card that failed to be born, so the feed just looks a bit
thin. Found on 2026-09-07, all pre-existing:

- **`UCL_CLINCHED` built a 38-character `push_title` against a 35-character CHECK
  constraint.** Every Champions League qualification card was rejected by Postgres and
  silently never existed. `WC_KNOCKOUT_ELIMINATED` the same, at 40–47 characters.
  `EUROPE_CLINCHED` reached 102 characters of push text for a long trigger summary.
- **`bash ${#var}` counts bytes, not characters, without a UTF-8 locale.** "Touré" and
  "£43m" each read one character longer than they are, so any push sitting near the 35/90
  cap was rejected for length it did not have. Football copy is full of é, ø, ü, ć and £.
- **A validator that only rejects teaches the routine to give up.** Replaying the 1,019
  routine cards from the World Cup through the hard-reject guards published **99** of them.
  Through the repair-first pipeline: **1,012**. The seven that still do not publish are all
  the same class — a results clause naming a club outside the league — which is the one
  thing genuinely worse than silence.

**The rule now.** Repair before you judge, and reserve rejection for content that would be
worse than silence.

1. **Auto-fix** everything mechanical — length, case, headline rows, missing punctuation,
   bracket tokens, name spelling. `repair_payload.py` on the routine side,
   `_shared/build-content-item.ts` on the Edge side.
2. **Voice and craft** reject once with a rewrite instruction, then publish anyway on
   `POST_NEWS_ATTEMPT=2` with the violation recorded.
3. **Never publishes, at any attempt**: prompt injection, PII, and a results clause naming
   a club outside the league. A wrong fact is worse than no card. Everything else is not.

**When you add a guard, ask which of the three it is.** The default answer is 1, then 2.
A new hard reject needs a reason why shipping the imperfect version would be worse than
the customer getting nothing.

## Adding a source

When you wire up a new feed or a new field:

1. Check a handful of values against something independent before you build on it. Assume nothing from the field name.
2. Write down here what it gets right and what it gets wrong, with the date.
3. If a field is wrong in a way a customer would notice, put the truth in our own table with a `*_verified_at` column and point every consumer at that.
4. Add a freshness check to the `stale-data-audit` skill in the same change.
