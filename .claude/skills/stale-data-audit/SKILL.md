---
name: stale-data-audit
description: Audit and refresh every surface in GoalDigger that carries football facts which rot — clubs, managers, squads, player cards, team-page prose, season labels, hardcoded lists and store copy. Run after a transfer window closes, at a season rollover, after a promotion/relegation change, when a manager is sacked, or whenever a user reports the app stating something out of date.
---

# Stale-data audit

GoalDigger states facts about real football. Facts rot on a schedule the code does not know about: a transfer window closes, a manager is sacked, three clubs go down. Nothing in the app fails when that happens. It keeps serving May's truth in September, confidently, to someone who paid for it.

This skill is the checklist that catches that. Work through every section. Report what was stale, what you fixed, and what only a human can decide.

**When to run it**
- A transfer window closes (early February and early September in England).
- A season rolls over (mid-June to mid-August).
- Promotion and relegation are decided (late May).
- A manager change is reported anywhere.
- A user says the app told them something wrong.
- Nothing above happened but it has been a month.

**The rule that generated this skill:** never trust a single upstream feed for a fact a human would notice being wrong. API-Football is right about scores and squads and wrong about managers. Where a feed cannot be trusted, the truth lives in a column in our database with a `*_verified_at` date, and this skill is what refreshes it.

## 0. Setup

```bash
cd /Users/anton/FantasyLeague
set -a && source backend/.env && set +a
P=/opt/homebrew/opt/libpq/bin/psql
```

Routines repo: `/Users/anton/goaldigger-routines`. Edge deploy: `cd backend && supabase functions deploy <name> --project-ref cwgpsmbunrocrofziqad --no-verify-jwt`.

Never fix cross-team data by looping a `callClaude()` Edge Function. Read `/BACKFILL_RULES.md` and the hard rule in `CLAUDE.md` first: SQL, then a claude.ai routine, then nothing else.

## 1. Which clubs are in the league

The one that breaks everything downstream. A club that is in `teams` but not in the league gets content nobody reads; a club in the league but not in `teams` gets an empty app.

```bash
$P "$SUPABASE_DB_URL" -At -F' | ' -c "select id,display_name,api_football_id,is_active from teams where league_id=39 order by is_active desc,id"
```

Check the 20 active rows against the current Premier League table on the web (`premierleague.com`, or a search for the season's promoted and relegated clubs). Then:

- A promoted club needs a `teams` row with the right `api_football_id`, `is_active=true`, and a `team_pages` row (section 4 creates it).
- A relegated club gets `is_active=false`. Do not delete it; its history and its `players` rows still resolve.
- The iOS `Team` enum must match exactly: `ios/GoalDigger/Models/Team.swift`, plus `displayName`, `shortName` and any crest asset. A club missing here cannot be picked in onboarding, and this needs an App Store build, so it is the long pole. Check it early.

```bash
diff <($P "$SUPABASE_DB_URL" -At -c "select id from teams where league_id=39 and is_active order by id") \
     <(sed -n '/enum Team/,/^}/p' ios/GoalDigger/Models/Team.swift | grep -oE '= "[a-z_]+"' | tr -d '= "' | sort)
```

## 2. Managers

**API-Football cannot be trusted here and never could.** Verified on 2026-09-06: its `/coachs?team=` payload omitted four sitting Premier League managers entirely (their own `/coachs?id=` record still named their previous club), and it listed assistants and caretakers with open stints, so "the most recent open stint" resolved to Bournemouth's assistant, Everton's assistant and Spurs' assistant.

The truth lives in `teams.manager_name` / `manager_photo_url` / `manager_started_on` / `manager_verified_at` (migration 085). Everything downstream reads that column: `team-page-generator` in `dynamic_only` mode, `fetch_team_page.sh`, and `post_team_page.sh`, which rejects any payload naming a different manager.

```bash
$P "$SUPABASE_DB_URL" -At -F' | ' -c "select id,manager_name,manager_started_on,manager_verified_at::date from teams where league_id=39 and is_active order by id"
```

Check every row against two independent web sources. `premierleague.com/en/managers` is authoritative and carries start dates; a second list (a news outlet's season manager guide) catches the case where the official page lags an appointment by a day. Be careful with lists that still name last season's clubs — that is how you can tell a page is stale.

To update, edit and re-run a copy of `backend/supabase/migrations/085_manager_override.sql` with the new values, or:

```sql
UPDATE teams SET manager_name='...', manager_photo_url='https://media.api-sports.io/football/coachs/<id>.png',
       manager_started_on='YYYY-MM-DD', manager_verified_at=now() WHERE id='<club>';
```

Find `<id>` (API-Football's coach id, which is also the photo path) even when the feed still has the manager at their old club:

```bash
curl -sS -H "x-apisports-key: $API_FOOTBALL_KEY" "https://v3.football.api-sports.io/coachs?search=<surname>" \
  | jq -r '.response[]? | "\(.id) | \(.firstname) \(.lastname) | \(.nationality)"'
```

Confirm the id is the right person before using it (`?id=<id>` returns their career). A wrong id publishes another man's face.

After updating, push the change into the pages and blank the prose that described the old manager, so the routine rewrites it:

```sql
UPDATE team_pages tp SET content = jsonb_set(tp.content, '{cards,manager}',
  COALESCE(tp.content->'cards'->'manager','{}'::jsonb)
    || jsonb_build_object('name', t.manager_name, 'photo_url', t.manager_photo_url,
                          'updated_at', to_char(now() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'))
    || CASE WHEN tp.content->'cards'->'manager'->>'name' IS DISTINCT FROM t.manager_name
            THEN jsonb_build_object('summary','', 'talking_point', NULL, 'summary_stale', true)
            ELSE '{}'::jsonb END, true), updated_at = now()
FROM teams t WHERE t.id = tp.team_id AND t.manager_name IS NOT NULL;
```

## 3. Squads, players and photos

`players` (api_player_id, team_id, name, position, photo_url) backs scorer faces in the live match box and the full-time articles. It is synced from API-Football's squad payload, which IS reliable, by `sync_players_from_squads()` (migration 084) on the `goaldigger-players-sync` cron at 05:30 UTC.

```bash
$P "$SUPABASE_DB_URL" -At -c "select public.sync_players_from_squads()"
$P "$SUPABASE_DB_URL" -At -F' | ' -c "select team_id,count(*),count(photo_url),max(updated_at)::date from players where team_id in (select id from teams where league_id=39 and is_active) group by 1 order by 1"
```

Expect 25 to 50 players per club and a photo for every one. A club stuck on an old date means `data-fetcher` is not storing squads for it: check `raw_fetch_logs` for `api_football_squad`.

Spot-check that the photos resolve, and watch for placeholders: API-Football serves a generic silhouette rather than a 404, so a "working" URL can still be a grey outline. Group by checksum, and any hash shared by several people is a placeholder.

```bash
$P "$SUPABASE_DB_URL" -At -c "select photo_url from players order by random() limit 20" \
  | while read -r u; do echo "$(curl -sS --max-time 15 "$u" | md5) $u"; done | sort | uniq -c -w 32
```

Do the same for the 20 manager photos. On 2026-09-06 seven of them shared two placeholder hashes: that is a known upstream gap, not a bug to chase, but say so in the report rather than claiming every manager has a headshot.

## 4. Team pages

`team_pages.content.cards` mixes three lifetimes, and only the first refreshes itself.

| Card | Written by | Cadence | Rots? |
|---|---|---|---|
| `form`, `next_fixture`, `standings`, `manager.name`, `manager.photo_url` | `team-page-generator` `dynamic_only` | every 2h via `goaldigger-daily-pipeline` | no |
| `manager.summary`, `form_summary`, `season.summary`, `next_fixture.preview`, `ones_to_know` | `gd-team-page` routine | Mondays 02:30 UTC | yes, this is the section that went five months stale |
| `basics`, `rivalry` | hand-seeded (migration 004), never overwritten | never | stadium renames, nothing else |

```bash
$P "$SUPABASE_DB_URL" -At -F' | ' -c "select c.key, count(*), min(left(c.value->>'updated_at',10)), max(left(c.value->>'updated_at',10)) from team_pages tp join teams t on t.id=tp.team_id, jsonb_each(tp.content->'cards') c where t.league_id=39 and t.is_active group by 1 order by 3"
$P "$SUPABASE_DB_URL" -At -c "select id from teams where league_id=39 and is_active and id not in (select team_id from team_pages)"
```

Anything in the prose row older than about six weeks is stale. Fire the routine and watch it:

```
RemoteTrigger action=run trigger_id=trig_015wVs1ZDsEaMYd7c99Fcy34   # gd-team-page
RemoteTrigger action=list_runs trigger_id=trig_015wVs1ZDsEaMYd7c99Fcy34
RemoteTrigger action=get_run_log session_id=<cse_...>
```

It takes roughly 45 minutes for 20 clubs. Then read the output as a customer would, not as a diff:

```bash
$P "$SUPABASE_DB_URL" -At -F' | ' -c "select team_id, content->'cards'->'manager'->>'name', left(content->'cards'->'season'->>'summary',110), (select string_agg(p->>'name',', ') from jsonb_array_elements(content->'cards'->'ones_to_know'->'players') p) from team_pages tp join teams t on t.id=tp.team_id where t.league_id=39 and t.is_active order by 1"
```

Read for tense and for last season's storylines: "two games left", "the title on the line", "Champions League final", a European place that was decided in May. Check every `ones_to_know` name is still at that club:

```bash
$P "$SUPABASE_DB_URL" -At -F' | ' -c "select tp.team_id, p->>'name', (select string_agg(pl.name,',') from players pl where pl.team_id=tp.team_id and lower(regexp_replace(pl.name,'^.*[. ]','')) = lower(regexp_replace(p->>'name','^.*[. ]',''))) from team_pages tp join teams t on t.id=tp.team_id, jsonb_array_elements(tp.content->'cards'->'ones_to_know'->'players') p where t.league_id=39 and t.is_active order by 1"
```

An empty third column means that player has left. Compare on surname: the squad feed abbreviates first names (`V. Gyökeres`), the cards spell them out.

## 5. Player dossiers

`player_cards` (T3 bottom sheet) is written by `gd-player-dossier` for whoever is in `ones_to_know`, so it lags a change there by one run and keeps rows for players who have left.

```bash
$P "$SUPABASE_DB_URL" -At -F' | ' -c "select pc.team_id,pc.player_name,pc.position,pc.updated_at::date from player_cards pc join teams t on t.id=pc.team_id where t.league_id=39 and t.is_active order by pc.updated_at limit 30"
```

Re-run `gd-player-dossier` (`trig_018j7fTzZ9Zt62yctyhiLJhG`) after section 4, and delete rows for players no longer in the squad and no longer in `ones_to_know`.

## 6. Season state, insider items, quiz

Same shape: LLM prose keyed to a moment in the season.

```bash
$P "$SUPABASE_DB_URL" -At -F' | ' -c "select team_id,phase,left(state_line,40),generated_at::date from team_season_state order by generated_at limit 25"
$P "$SUPABASE_DB_URL" -At -F' | ' -c "select team_id,count(*),max(created_at)::date from team_insider_items group by 1 order by 3 limit 25"
```

`phase` must match the calendar: `pre_season` in July, `mid_season` from late August, `run_in` from April, `off_season` in June. A phase that disagrees with the date means `gd-season-state` (`trig_01TES8jphjFvp8Qf9e87bDoF`) has not run.

## 7. Hardcoded lists and season labels

Grep for last season's clubs and for a hardcoded year. Both have bitten us: the routines iterated the previous season's 20 clubs for the first month of 2026-27, so Coventry and Hull had literally no content, and `SEASON` was pinned to `2025`.

```bash
grep -rn "west_ham\|wolves\|burnley\|leicester\|southampton" /Users/anton/goaldigger-routines/*.md /Users/anton/goaldigger-routines/*.sh | grep -v backfill_ | grep -v non_pl=
grep -rn "2025-26\|2025/26\|SEASON=\"2025\"\|season=2025" /Users/anton/goaldigger-routines backend/supabase/functions --include=*.md --include=*.sh --include=*.ts
```

Every club list must come from the `teams` table at runtime (`fetch_news.sh` writes `/tmp/_teams.txt`), and every season must be computed from the date (July onwards is the new season). A literal list in a prompt is acceptable only as an illustration alongside the sentence naming `/tmp/_teams.txt` as authoritative.

Also check the relegated clubs are not still receiving content:

```bash
$P "$SUPABASE_DB_URL" -At -F' | ' -c "select team_id,count(*) from content_items where created_at>now()-interval '7 days' and team_id not in (select id from teams where is_active) group by 1"
```

## 8. Grounding guards

These stop a model writing last season's memory into today's article. Confirm they are present, and add a case whenever a new failure appears.

- `post_news.sh`: rejects a results clause naming a non-Premier-League club (unless the sentence is about a cup tie); a bracket token iOS does not substitute (it knows only `[his name]`, `[her name]` and their capitalised and possessive forms, per `AppState.personalise`); and any placeholder at all in `push_title`, `push_text`, `headline`, `immersive_headline` or `everyone_talking_headline`, because nothing personalises those. If you add a surface that renders content text, check whether it calls `personalise()` and update that field list.
- Update the `non_pl` club list at a promotion or relegation.
- `post_team_page.sh`: rejects players outside the current squad, a manager who is not `teams.manager_name`, last-season phrasing, fan voice, `?`/`!`, and placeholders other than `[his name]`.
- `MATCHDAY_PROMPT.md`: results, season record and a player's club come only from the fetched payloads.

Test a guard rather than trusting it, using the sentence that got through last time. The routines repo needs its own env names:

```bash
cd /Users/anton/goaldigger-routines
set -a && source /Users/anton/FantasyLeague/backend/.env && set +a
export SUPABASE_SERVICE_KEY="$SUPABASE_SERVICE_ROLE_KEY"
cat > /tmp/t.json <<'EOF'
{"team_id":"chelsea","type":"news","headline":"Chelsea beaten","body":"It is Chelsea first loss of the season, snapping wins over Brighton, Luton, and Fulham.","push_text":"Chelsea lost the derby.","push_title":"Two good minutes","talking_points":["a","b","c"]}
EOF
bash post_news.sh /tmp/t.json 2>&1 | grep -E "^ERROR|found:"   # expect the non-PL rejection
```

A payload that clears every guard fails at the POST with `HTTP 401` on this machine (the local REST keys have been dead since 2026-05-11), which is how you tell "validators passed" from "validators rejected" without writing to production.

## 9. Store copy and marketing

The listing is the promise a paying customer measures the app against, and no cron touches it.

```bash
grep -rn "Arsenal, Manchester United, or West Ham\|3am\|spam" APP_STORE_STRATEGY.md APP_STORE_V2.0_COPY.md 2>/dev/null
```

Club names, club counts, feature claims and screenshots all go stale. Anything the app no longer does must come out of App Store Connect. This one needs Anton; list it, do not edit the listing yourself.

## 10. iOS constants

```bash
grep -rn "hideAfter\|WCSeason" ios/GoalDigger/Models/FeedContext.swift
```

`WCSeason.hideAfter` is a hardcoded date that hides the World Championship surfaces. Any date, country list or club list compiled into the app needs a build and a release, so raise it as its own task with the lead time called out.

## Reporting

Write the result into `SJALVRANNSAKAN_2026-09.md` (or the current audit report) as a numbered finding: the evidence with the query that produced it, what a customer would have seen, what you changed, and what is left. Update `MEMORY.md` if a routine, trigger id or table changed.

## Extending this skill

**Whenever you add a surface that holds a manually-maintained or slowly-rotting fact, add it here in the same pass.** A new surface is one of:

- a new column or table a human fills in by hand (add it with a `*_verified_at` timestamp, and add a section here saying which web source verifies it),
- a new LLM-written card, item type or feed surface (add a freshness query and say who rewrites it and how often),
- a new hardcoded list, date or season label in a prompt, script, Edge Function or Swift file (add it to the grep in section 7),
- a new external feed (say in one line which of its fields we trust and which we do not, the way section 2 does for managers).

The test for whether a surface belongs here: if it were six months out of date, would a paying customer notice? If yes, it belongs here, with a command that shows its age.
