# App fixes from Anton's screenshots, 2026-10-27

Status: plan. Each item says what is wrong (with file:line from the read-only
investigation), the fix, and whether it ships from the backend today or needs
an app release. The lineup talking point (`parked`) is listed last.

---

## A. Ships from the backend — no app release

**A1. Live card shows the whole league table mid-match, not the scorers.**
`live-brief-current` attaches `team_pages.cards.standings` to every live
brief (`live-brief-current/index.ts:180-214`). It was built 2026-06-16 for a
four-row World Cup group (`a591cb8`); for a PL club the same field is the
20-row league table. Scorers already flow end to end (`goal_events` →
`scorers`) and the card draws them when there are goals.
Fix: send `standings: null` unless the match is a World Championship group
game. The card already hides the block when it is nil.

**A2. "LIVE · LIVE".** The backend sends `trigger_label: null` outside half
time (`:175`), the app turns null into "LIVE", next to a hard-coded "LIVE".
Fix: send the period — "1ST HALF", "2ND HALF", "EXTRA TIME", "PENALTIES".
Old builds already show unknown labels upper-cased, and the minute stays.

**A3. Live Activities that never go away — backend half.**
- The end push is sent once and `la_ended` is set even if nothing was sent
  (`match-watcher/index.ts:1731-1756`). Fix: keep sending the end every tick
  until ~30 min after FT, and only mark ended once one send succeeded.
- Abandoned / postponed / suspended matches never end an activity (only
  FT/AET/PEN count, `:77`). Fix: end on ABD, CANC, PST, AWD, WO, and on SUSP/INT
  after a timeout.
- New sweeper cron: any active update token whose fixture kicked off more
  than ~3 h ago and is not live gets `event: end` with an immediate
  dismissal, then is deactivated. Covers scheduler outages like 21–25 Oct.

**A4. Europa League news is messy.** Produced by `gd-europe` with
`COMPETITION_PROMPT.md`, which says "you write the competition, not the
club" (`:3`) and lists no English club among Europa League heavyweights
(`:38`) — so "Benfica v Celtic, Juventus at Celta, Milan at Salzburg" is what
it was told to write. Fix, in code first (lesson 77):
- `fetch_competition.sh` adds a `focus` block per English club in it (rank,
  points, last result, next game) and a code-decided subject: our clubs if
  they play in the window, else "outside-only".
- `post_news.sh`, for competition cards: the headline must name one of our
  clubs (exception: a significance-2 elimination/final); at most two outside
  clubs per card, one in the headline; level-1 info card is mandatory and
  must say what this means for a club she might follow; outside-only Europa /
  Conference League cards are rejected.
- Prompt: rewrite the Europa League row around Bournemouth, Palace and
  Sunderland, add a "who is this for / what does not matter" section, and add
  this card as a bad example.

**A5. Lille's crest missing in the fixture card.** The crest comes only from
API ids the routine writes into `info_cards[].fixture`; there is no fallback
(`ContentItem.swift:266-267`). The routine omitted or got Lille's id wrong.
Fix: `post_news.sh` fills or corrects `home_api_id` / `away_api_id` from the
fixture feed by fixture id, so the model never supplies them.

---

## B. Needs an app release

**B1. Team page: skeleton, then "Couldn't load", and Try again does nothing.**
No cache for a newly followed second club, a 10 s request timeout on a large
row, and errors swallowed silently (`TeamPageView.swift:1617-1691`,
`APIClient.swift:91-101`). Try again does run — it just repeats the same 10 s
wait into the same error, with no sign it is retrying. Arsenal hides the same
failure behind its cache. Fix:
- a longer timeout for `team_pages` (it is one big JSON row);
- one automatic retry with backoff, and Try again shows a spinner;
- log the error (client-error-alert, throttled) so a failure reaches the
  dev phone instead of vanishing;
- the skeleton scrolls instead of clipping (the half-circle crest).
Also check, on the server, how long `team_pages?team_id=eq.liverpool` takes
and how big the row is — the outage week makes the backend a suspect too.

**B2. Arsenal crest grey on the team page header.** `TeamCrestView` is a bare
`AsyncImage`: loading and failure look the same, and a failure never retries
(`TeamCrestView.swift:36-46`). The header rebuilds several times while it
loads, which can drop the image. Fix: retry once on failure and keep the
image once loaded; bundle the 20 club crests in the app so ours never depend
on the CDN.

**B3. Gabriel has no info or link in an article.** There is no player linking
in articles at all — nothing ever scanned headlines for names. And every
matcher keys on the surname, so a mononym ("Gabriel" for Gabriel Magalhães)
fails everywhere. Fix:
- a `known_as` column on `players` (Gabriel, Raya, Ødegaard…), filled once by
  SQL, used by every matcher;
- articles get a "Who's who" row of the club's players named in the headline
  and info cards, each opening the existing `PlayerCardModal`.

**B4. Live Activities — app half.** The app's cleanup only ends activities in
state `.active`, but an activity whose end push was missed is `.stale` by
then, so the cleanup never touches the very ones it is for
(`LiveActivityManager.swift:130`). Fix: end anything not live that is not
already ended/dismissed; re-register update tokens for activities that
already exist on launch; stop swallowing registration errors.

**B5. Live card scorers per side** (after A1): split `scorers` into home and
away columns instead of one list.

**B6. "Pre-game ›" on His Team should stay on the page.** Commit `10ee095`
(7 Oct) made the pink strip leave the page for My Turn. Nothing inline was
deleted — the kickoff line, preview, opponent's ones to watch and the line to
say are still in the card, now only reachable by tapping the top half. Fix:
the strip expands the card in place again, as before.

**B7. Tournament explanations.** Under each table on His Team, and on
Champions / Europa / Conference League and cup posts in the feed, a tappable
one-line explanation of the competition, from the existing glossary
(`GlossaryService`, already has "Europa League").

**B8. Europa League table and European dates.** By design a club page shows
its own European table — Palace, Bournemouth and Sunderland already get
Premier League | Europa League. Real gaps:
- the "still in Europe" check only sees the last 3 games and 3 days of logs,
  so a club between the league phase and the knock-outs loses its table
  (`team-page-generator/index.ts:333-360`). Fix: read it from the
  tournament's own fixtures and table;
- the European table is only rebuilt with the domestic one (`:1097`);
- the calendar shows 15 rows, about seven weeks; raise it so the rest of the
  league phase is visible.

---

## C. Decision needed: the Matchday tab (`claude/matchday-tab`)

Built 7–8 Oct, not merged: a Matchday tab (Before = Pre-game moved out of My
Turn, After = result, "say this now", scorers, three numbers), tabs become
Feed · Matchday · club · My Turn, Settings moves behind a gear. It builds and
runs (screenshots sent). It is 7 commits ahead and 27 behind; it conflicts
in four files and with today's pre-game push routing, which would point at
Matchday › Before instead.

---

## D. Parked: lineup talking point

Designed in the approved plan (fold into the T−30 kickoff push, dry run for
two weekends). Data checked: `players.api_player_id` matches the lineup ids,
`league_starts` gives "regular". Nothing written yet.

---

## Suggested order

1. **A1, A2, A5** — small, backend, visible on the next match.
2. **A3** — before the next match, so activities stop piling up.
3. **B1, B2, B4, B6** — the bugs she sees, one app build.
4. **A4** — the Europa League card rules, before Thursday's games.
5. **C** — merge decision, then **B7, B3, B5, B8**.
6. **D** — lineups.
