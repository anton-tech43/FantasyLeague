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
| `/players/squads` | who is at a club, position, shirt number, photo | The basis of `sync_players_from_squads()` (migration 084). Cross-checked against transfers we could verify independently; it correctly had Bruno Guimarães at Arsenal after his summer move. Names come abbreviated (`V. Gyökeres`), so **match on surname**, never on the full string. |
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

- **Season is the starting year.** 2026-27 is `season=2026`. Compute it from the date (July onwards is the new season), never hardcode it — a pinned `2025` served the previous season's table for the first month of 2026-27.
- **Quota is shared** with `match-watcher`'s per-minute polling. Prefer reading `raw_fetch_logs` (at most 2 hours old) over a fresh call.

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

## Adding a source

When you wire up a new feed or a new field:

1. Check a handful of values against something independent before you build on it. Assume nothing from the field name.
2. Write down here what it gets right and what it gets wrong, with the date.
3. If a field is wrong in a way a customer would notice, put the truth in our own table with a `*_verified_at` column and point every consumer at that.
4. Add a freshness check to the `stale-data-audit` skill in the same change.
