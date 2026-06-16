# 067 — team strength rank seed notes

Companion to `067_team_strength_rank.sql`. Records exactly which FIFA ranking
was used, how each World Championship country was mapped to a `teams.id` slug,
and any caveats. These numbers are user-facing (pre-game favorite tags,
post-result upset framing), so they were cross-checked.

## Source

- **Ranking used:** FIFA / Coca-Cola Men's World Ranking, **published 11 June 2026**
  (the most recent published edition as of the migration date, 2026-06-16).
- **Primary source (positions 1–50):** ESPN, "FIFA Men's Top 50 World Rankings:
  June 2026" — https://www.espn.com/soccer/story/_/id/46664763/fifa-mens-top-50-world-rankings
  (article timestamp June 11, 2026).
- **Secondary / lower-ranked positions (51–85) and cross-check:**
  - whereig.com, "FIFA World Rankings 2026" (states "based on the official
    rankings released on 11 June 2026") — https://www.whereig.com/football/fifa-world-rankings.html
  - Per-country confirmations via web search for the same 11 June 2026 edition
    (South Africa 60, Bosnia 64, etc. — see notes below).
- **Official index (for re-verification):** https://inside.fifa.com/fifa-world-ranking/men
  (page confirms "Last official update: 11 June 2026").

Rank semantics: integer position, **lower = stronger** (1 = best in the world).

## Slug source

The authoritative WC slug list is the keys of `WC_COUNTRY_META` in
`backend/supabase/functions/_shared/wc-countries.ts`. There are **48** of them.
All 48 were confidently mapped — **no unmapped countries**.

## Country → FIFA rank (11 June 2026)

Sorted by rank (strongest first).

| Rank | teams.id slug        | WC_COUNTRY_META name | FIFA listing name        |
|-----:|----------------------|----------------------|--------------------------|
| 1    | argentina            | Argentina            | Argentina                |
| 2    | spain                | Spain                | Spain                    |
| 3    | france               | France               | France                   |
| 4    | england              | England              | England                  |
| 5    | portugal             | Portugal             | Portugal                 |
| 6    | brazil               | Brazil               | Brazil                   |
| 7    | morocco              | Morocco              | Morocco                  |
| 8    | netherlands          | Netherlands          | Netherlands              |
| 9    | belgium              | Belgium              | Belgium                  |
| 10   | germany              | Germany              | Germany                  |
| 11   | croatia              | Croatia              | Croatia                  |
| 13   | colombia             | Colombia             | Colombia                 |
| 14   | mexico               | Mexico               | Mexico                   |
| 15   | senegal              | Senegal              | Senegal                  |
| 16   | uruguay              | Uruguay              | Uruguay                  |
| 17   | usa                  | USA                  | USA / United States      |
| 18   | japan                | Japan                | Japan                    |
| 19   | switzerland          | Swiss                | Switzerland              |
| 20   | iran                 | Iran                 | Iran (IR Iran)           |
| 22   | turkiye              | Türkiye              | Türkiye                  |
| 23   | ecuador              | Ecuador              | Ecuador                  |
| 24   | austria              | Austria              | Austria                  |
| 25   | south_korea          | Korea                | South Korea (Korea Rep.) |
| 27   | australia            | Australia            | Australia                |
| 28   | algeria              | Algeria              | Algeria                  |
| 29   | egypt                | Egypt                | Egypt                    |
| 30   | canada               | Canada               | Canada                   |
| 31   | norway               | Norway               | Norway                   |
| 33   | ivory_coast          | Ivory Coast          | Ivory Coast (Côte d'Ivoire) |
| 34   | panama               | Panama               | Panama                   |
| 38   | sweden               | Sweden               | Sweden                   |
| 40   | czech_republic       | Czechia              | Czechia                  |
| 41   | paraguay             | Paraguay             | Paraguay                 |
| 42   | scotland             | Scotland             | Scotland                 |
| 45   | tunisia              | Tunisia              | Tunisia                  |
| 46   | congo_dr             | DR Congo             | Congo DR (DR Congo)      |
| 50   | uzbekistan           | Uzbekistan           | Uzbekistan               |
| 56   | qatar                | Qatar                | Qatar                    |
| 57   | iraq                 | Iraq                 | Iraq                     |
| 60   | south_africa         | S. Africa            | South Africa             |
| 61   | saudi_arabia         | Saudi                | Saudi Arabia             |
| 63   | jordan               | Jordan               | Jordan                   |
| 64   | bosnia_herzegovina   | Bosnia               | Bosnia and Herzegovina   |
| 67   | cape_verde           | Cape Verde           | Cape Verde (Cabo Verde)  |
| 73   | ghana                | Ghana                | Ghana                    |
| 82   | curacao              | Curaçao              | Curaçao                  |
| 83   | haiti                | Haiti                | Haiti                    |
| 85   | new_zealand          | NZ                   | New Zealand              |

48 rows. Every WC slug is present exactly once; rank numbers are all distinct.

## Mapping notes / naming caveats handled

- **usa** ← "USA" / "United States" — same team.
- **south_korea** ← FIFA "South Korea" (sometimes listed as "Korea Republic").
- **iran** ← FIFA "Iran" (sometimes listed as "IR Iran").
- **ivory_coast** ← FIFA "Ivory Coast" (sometimes "Côte d'Ivoire").
- **congo_dr** ← FIFA "Congo DR" / "DR Congo" (the Democratic Republic of the
  Congo — NOT Congo-Brazzaville).
- **turkiye** ← FIFA "Türkiye" (formerly "Turkey").
- **czech_republic** ← FIFA "Czechia".
- **cape_verde** ← FIFA "Cape Verde" / "Cabo Verde".

## Verification caveats

- **bosnia_herzegovina = 64:** the official 11 June 2026 edition. Two corroborating
  sources (whereig.com and pre-tournament reporting describing Bosnia as Canada's
  group opponent "ranked 64th"). A loose secondary search returned 65, and a
  *daily-tracker* site showed 71 dated 12 June 2026; both are treated as outliers
  vs. the official 11 June figure. Used **64**.
- **south_africa = 60:** not in the top-50 ESPN list; confirmed via search and
  whereig.com for the 11 June 2026 edition (also reported as the lowest-ranked
  team in its WC group).
- Positions for the 11 sub-50 teams (qatar 56, iraq 57, south_africa 60,
  saudi_arabia 61, jordan 63, bosnia 64, cape_verde 67, ghana 73, curacao 82,
  haiti 83, new_zealand 85) come from whereig.com + targeted searches rather than
  ESPN's top-50; whereig.com explicitly attributes them to the 11 June 2026 edition.

## Unmapped countries

**None.** All 48 WC participants were confidently mapped.

## Clubs

Premier League (and any other `entity_type='club'`) rows are intentionally left
with `strength_rank = NULL`. Their strength is derived at runtime from current
league standings position, so there is nothing to seed.
