-- audit/2026-09/queries.sql
-- Självrannsakan 2026-09 — READ-ONLY query-paket för produktions-Supabase.
--
-- Kör:   cd audit/2026-09 && ./run_audit.sh            (läser SUPABASE_DB_URL ur backend/.env)
-- eller: psql "$SUPABASE_DB_URL" -X -q -v ON_ERROR_STOP=0 -f queries.sql   (från audit/2026-09/)
--
-- Varje block skriver EN CSV till out/. Inget skrivs till databasen. Inga
-- device tokens eller per-användar-rader väljs ut (bara aggregat).
--
-- Tidsfönster (justera vid behov):
--   PL-nu:      2026-08-01 → nu
--   VM-retro:   2026-06-28 → 2026-07-20  (slutspel: R32 28 jun … final 19 jul)
--   Snapshot:   2026-06-01 → nu          (pipeline_health gallras efter 90 d — ta NU)
--
-- Alla tider levereras både i UTC och Europe/Stockholm (CEST i hela fönstret).

\pset format csv
\pset footer off
\set ON_ERROR_STOP off
\set pl_start '2026-08-01'
\set wc_start '2026-06-28'
\set wc_end   '2026-07-20'
\set snap_start '2026-06-01'

-- ============================================================================
-- B1 · DRIFTFACIT — prod ≠ git
-- ============================================================================

-- 01 Alla crons som faktiskt finns i DB (inkl. sådana som skapats utanför migrationer,
--    t.ex. goaldigger-archive-old-content). command visar exakt vad de gör.
\o out/01_cron_jobs.csv
SELECT jobid, jobname, schedule, active, nodename, database, command
FROM cron.job
ORDER BY jobname;
\o

-- 02 Cron-körningar senaste 14 d (finns i pg_cron ≥1.4; hoppas över om tabellen saknas)
\o out/02_cron_runs_14d.csv
SELECT j.jobname, r.status, count(*) AS runs,
       min(r.start_time) AS first_run_utc, max(r.start_time) AS last_run_utc
FROM cron.job_run_details r JOIN cron.job j USING (jobid)
WHERE r.start_time > now() - interval '14 days'
GROUP BY 1, 2 ORDER BY 1, 2;
\o

-- 03 Teams-snapshot: A6-kontroll (league_id per entitet, Coventry/Hull api-id, is_active)
\o out/03_teams.csv
SELECT id, display_name, entity_type, league_id, is_active, api_football_id, strength_rank
FROM teams ORDER BY entity_type, league_id, id;
\o

\o out/03b_teams_by_league.csv
SELECT entity_type, league_id, is_active, count(*) FROM teams GROUP BY 1,2,3 ORDER BY 1,2,3;
\o

-- 04 Schema-drift: constraints + kolumner på content_items (status='archived'?)
\o out/04_content_items_constraints.csv
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE conrelid = 'public.content_items'::regclass ORDER BY conname;
\o

\o out/04b_content_items_columns.csv
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='content_items' ORDER BY ordinal_position;
\o

\o out/04c_triggers.csv
SELECT event_object_table, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers WHERE trigger_schema='public' ORDER BY 1,2;
\o

-- 05 Vilka migrationer prod tror att den har
\o out/05_migrations_applied.csv
SELECT version, name FROM supabase_migrations.schema_migrations ORDER BY version;
\o

-- ============================================================================
-- A11 · RETENTION-SNAPSHOT (tidskritiskt — pipeline_health gallras efter 90 d)
-- ============================================================================

\o out/06_retention_overview.csv
SELECT 'pipeline_health' AS tbl, stage AS bucket, count(*) AS rows,
       min(created_at) AS oldest_utc, max(created_at) AS newest_utc
FROM pipeline_health GROUP BY stage
UNION ALL
SELECT 'content_items', status, count(*), min(created_at), max(created_at) FROM content_items GROUP BY status
UNION ALL
SELECT 'content_items', 'pipeline_source='||pipeline_source, count(*), min(created_at), max(created_at) FROM content_items GROUP BY pipeline_source
UNION ALL
SELECT 'raw_fetch_logs', 'all', count(*), min(fetched_at), max(fetched_at) FROM raw_fetch_logs
UNION ALL
SELECT 'match_status_state', 'league='||league_id, count(*), min(kickoff_time), max(kickoff_time) FROM match_status_state GROUP BY league_id
UNION ALL
SELECT 'matchday_reminders_sent', 'all', count(*), min(sent_at), max(sent_at) FROM matchday_reminders_sent
UNION ALL
SELECT 'live_match_briefs', 'all', count(*), min(generated_at), max(generated_at) FROM live_match_briefs
UNION ALL
SELECT 'saturday_quiz_items', 'all', count(*), min(published_at), max(published_at) FROM saturday_quiz_items
UNION ALL
SELECT 'team_insider_items', 'all', count(*), min(published_at), max(published_at) FROM team_insider_items
ORDER BY 1, 2;
\o

-- 06b FULL dump av pipeline_health sedan 1 jun (aggregerade rader, ingen PII)
\o out/06b_pipeline_health_dump.csv
SELECT id, team_id, stage, status, duration_ms, message, content_item_id, target,
       http_status, response_excerpt, error_class,
       created_at AS created_utc, created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm
FROM pipeline_health
WHERE created_at >= :'snap_start'
ORDER BY created_at;
\o

-- 07 FULL dump av match_status_state (VM + PL) — loggen för live-pushar
\o out/07_match_status_state.csv
SELECT fixture_id, league_id, home_team_id, away_team_id, status, home_goals, away_goals,
       elapsed, kickoff_time AS kickoff_utc, kickoff_time AT TIME ZONE 'Europe/Stockholm' AS kickoff_sthlm,
       last_checked, fired_finished_at, fired_finished_at AT TIME ZONE 'Europe/Stockholm' AS fired_sthlm,
       EXTRACT(EPOCH FROM (fired_finished_at - kickoff_time))/60 AS fired_minutes_after_kickoff,
       briefs_fired, matchday_fire_capped, la_started, la_sig, la_ended,
       jsonb_array_length(COALESCE(goal_events,'[]'::jsonb)) AS n_goal_events
FROM match_status_state ORDER BY kickoff_time;
\o

-- ============================================================================
-- B2 · TIDSLINJE PL (1 aug → nu)
-- ============================================================================

-- 08 Huvuddataset: alla items för PL-klubbar (aktiva + inaktiva) sedan pl_start
\o out/08_pl_items.csv
SELECT c.id, c.team_id, t.is_active AS team_active, c.type, c.pipeline_source, c.consequence_type,
       c.status, c.push_eligible,
       c.created_at AS created_utc, c.created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm,
       c.published_at AS published_utc,
       c.pushed_at AS pushed_utc, c.pushed_at AT TIME ZONE 'Europe/Stockholm' AS pushed_sthlm,
       EXTRACT(EPOCH FROM (c.pushed_at - c.created_at))/60 AS push_latency_min,
       to_char(c.pushed_at AT TIME ZONE 'Europe/Stockholm','HH24') AS pushed_hour_sthlm,
       c.kickoff_time AS kickoff_utc, c.match_id, c.preview_fixture_id,
       c.headline, c.push_title, c.push_text, c.immersive_headline, c.immersive_context,
       c.immersive_context_fallback, c.talking_points, c.emotional_context,
       c.everyone_talking, c.everyone_talking_headline, c.worth_knowing, c.affected_team_ids,
       length(c.body) AS body_len, c.body
FROM content_items c JOIN teams t ON t.id = c.team_id
WHERE t.league_id = 39 AND c.created_at >= :'pl_start'
ORDER BY c.created_at;
\o

-- 09 Pushar per lokal timme (Stockholm) — nattpush-profil (A4)
\o out/09_pushes_by_hour_sthlm.csv
SELECT to_char(c.pushed_at AT TIME ZONE 'Europe/Stockholm','HH24') AS hour_sthlm,
       count(*) AS pushed_items, count(DISTINCT c.team_id) AS teams
FROM content_items c JOIN teams t ON t.id=c.team_id
WHERE t.league_id=39 AND c.pushed_at >= :'pl_start'
GROUP BY 1 ORDER BY 1;
\o

-- 10 Nattpushar 22:00–06:59 Stockholm
\o out/10_night_pushes.csv
SELECT c.id, c.team_id, c.type, c.pushed_at AT TIME ZONE 'Europe/Stockholm' AS pushed_sthlm,
       c.created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm, c.push_title, c.push_text
FROM content_items c JOIN teams t ON t.id=c.team_id
WHERE t.league_id=39 AND c.pushed_at >= :'pl_start'
  AND (EXTRACT(HOUR FROM c.pushed_at AT TIME ZONE 'Europe/Stockholm') >= 22
       OR EXTRACT(HOUR FROM c.pushed_at AT TIME ZONE 'Europe/Stockholm') < 7)
ORDER BY c.pushed_at;
\o

-- 11 Samma-lag-pushar inom 5 min (dubbletter/burst trots 5-min-throttle)
\o out/11_same_team_pushes_within_5min.csv
SELECT a.team_id, a.id AS item_a, b.id AS item_b,
       a.pushed_at AT TIME ZONE 'Europe/Stockholm' AS pushed_a_sthlm,
       b.pushed_at AT TIME ZONE 'Europe/Stockholm' AS pushed_b_sthlm,
       EXTRACT(EPOCH FROM (b.pushed_at - a.pushed_at))/60 AS gap_min,
       a.push_title AS title_a, b.push_title AS title_b
FROM content_items a JOIN content_items b
  ON a.team_id=b.team_id AND a.id<b.id
 AND b.pushed_at BETWEEN a.pushed_at AND a.pushed_at + interval '5 minutes'
JOIN teams t ON t.id=a.team_id
WHERE t.league_id=39 AND a.pushed_at >= :'pl_start'
ORDER BY a.pushed_at;
\o

-- 12 Aldrig skickat: push-berättigat, publicerat, men pushed_at saknas (>24 h)
\o out/12_never_pushed.csv
SELECT c.id, c.team_id, c.type, c.status, c.created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm,
       c.published_at, c.push_title
FROM content_items c JOIN teams t ON t.id=c.team_id
WHERE t.league_id=39 AND c.created_at >= :'pl_start'
  AND c.push_eligible AND c.status='published' AND c.pushed_at IS NULL
  AND c.published_at < now() - interval '24 hours'
ORDER BY c.created_at;
\o

-- 13 pipeline_health per dag × stage × status (leverans, fel, tysta dagar)
\o out/13_pipeline_health_daily.csv
SELECT (created_at AT TIME ZONE 'Europe/Stockholm')::date AS day_sthlm, stage, status, count(*)
FROM pipeline_health WHERE created_at >= :'pl_start'
GROUP BY 1,2,3 ORDER BY 1,2,3;
\o

-- 14 APNs-fel i detalj
\o out/14_apns_failures.csv
SELECT created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm, team_id, status, error_class,
       http_status, message, content_item_id
FROM pipeline_health
WHERE stage='apns_send' AND status<>'success' AND created_at >= :'pl_start'
ORDER BY created_at;
\o

-- 15 Matchday-kedjan PL: FT-observation → gd-matchday-fire → item
\o out/15_pl_matchday_chain.csv
SELECT m.fixture_id, m.home_team_id, m.away_team_id, m.status, m.home_goals, m.away_goals,
       m.kickoff_time AT TIME ZONE 'Europe/Stockholm' AS kickoff_sthlm,
       m.fired_finished_at AT TIME ZONE 'Europe/Stockholm' AS fired_sthlm,
       EXTRACT(EPOCH FROM (m.fired_finished_at - m.kickoff_time))/60 AS fired_min_after_kickoff,
       m.briefs_fired, m.matchday_fire_capped,
       (SELECT count(*) FROM content_items c WHERE c.type='matchday' AND c.match_id = m.fixture_id::text) AS matchday_items,
       (SELECT min(c.created_at) AT TIME ZONE 'Europe/Stockholm' FROM content_items c WHERE c.type='matchday' AND c.match_id = m.fixture_id::text) AS first_item_sthlm,
       (SELECT string_agg(ph.status||':'||COALESCE(ph.error_class,''),' | ') FROM pipeline_health ph
          WHERE ph.stage IN ('matchday_fire','live_brief_fire') AND ph.target LIKE '%'||m.fixture_id||'%') AS fire_log
FROM match_status_state m
WHERE m.league_id=39 AND m.kickoff_time >= :'pl_start'
ORDER BY m.kickoff_time;
\o

-- 16 Förmatch-pushar PL: matchday-reminder (förväntat 0 = A2) + morning-push-rader
\o out/16_prematch_pushes.csv
SELECT 'matchday_reminders_sent' AS src, r.team_id, t.entity_type,
       r.kickoff_time AT TIME ZONE 'Europe/Stockholm' AS kickoff_sthlm,
       r.sent_at AT TIME ZONE 'Europe/Stockholm' AS sent_sthlm, NULL::text AS message
FROM matchday_reminders_sent r JOIN teams t ON t.id=r.team_id WHERE r.sent_at >= :'pl_start'
UNION ALL
SELECT 'pipeline_health:'||stage, team_id, NULL, NULL,
       created_at AT TIME ZONE 'Europe/Stockholm', status||' '||COALESCE(message,'')
FROM pipeline_health WHERE stage ILIKE '%morning%' AND created_at >= :'pl_start'
ORDER BY 5;
\o

-- 17 cron_invoke per jobb per dag — luckor = tysta avbrott
\o out/17_cron_invoke_daily.csv
SELECT (created_at AT TIME ZONE 'Europe/Stockholm')::date AS day_sthlm, target, status, count(*)
FROM pipeline_health WHERE stage='cron_invoke' AND created_at >= :'pl_start'
GROUP BY 1,2,3 ORDER BY 1,2,3;
\o

-- 17b routine_post per dag × routine-version (post_news.sh-tagg) — vilken kod kördes
\o out/17b_routine_posts_daily.csv
SELECT (created_at AT TIME ZONE 'Europe/Stockholm')::date AS day_sthlm, status, count(*),
       min(message) AS sample_message
FROM pipeline_health WHERE stage='routine_post' AND created_at >= :'pl_start'
GROUP BY 1,2 ORDER BY 1,2;
\o

-- ============================================================================
-- B3 · INNEHÅLL PL — deterministiska kontroller (hela populationen)
-- ============================================================================

-- 18 Items per lag sedan pl_start (Coventry/Hull förväntat 0 = A1; inaktiva lag = slöseri)
\o out/18_items_per_team.csv
SELECT t.id AS team_id, t.is_active, count(c.id) AS items,
       count(c.id) FILTER (WHERE c.pushed_at IS NOT NULL) AS pushed,
       count(c.id) FILTER (WHERE NOT c.push_eligible) AS feed_only,
       count(c.id) FILTER (WHERE c.type='matchday') AS matchday,
       count(c.id) FILTER (WHERE c.type='sunday_brief') AS sunday_briefs,
       min(c.created_at) AT TIME ZONE 'Europe/Stockholm' AS first_sthlm,
       max(c.created_at) AT TIME ZONE 'Europe/Stockholm' AS last_sthlm
FROM teams t LEFT JOIN content_items c ON c.team_id=t.id AND c.created_at >= :'pl_start'
WHERE t.league_id=39
GROUP BY t.id, t.is_active ORDER BY t.is_active DESC, items DESC;
\o

-- 19 content-audit-lintern: tabellpåståenden som motsäger tabellen
\o out/19_content_audit_findings.csv
SELECT created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm, team_id, status, message, content_item_id
FROM pipeline_health WHERE stage='content_audit' AND status IN ('failure','partial') AND created_at >= :'pl_start'
ORDER BY created_at;
\o

-- 20 Säsongsglidning i text (A1): "2025-26", "last season", förra säsongens tabell
\o out/20_stale_season_text.csv
SELECT c.id, c.team_id, c.type, c.created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm,
       c.pushed_at IS NOT NULL AS pushed, c.headline, left(c.body, 300) AS body_start
FROM content_items c JOIN teams t ON t.id=c.team_id
WHERE t.league_id=39 AND c.created_at >= :'pl_start'
  AND (c.headline||' '||c.body||' '||COALESCE(c.push_text,'')) ~* '2025[-/]26|last season|2025-26 season|title race.*2025'
ORDER BY c.created_at;
\o

-- 21 Längdtak (post_news.sh: push_title ≤35, push_text ≤90, headline ≤160, immersiv rad ≤22)
\o out/21_length_caps.csv
SELECT c.id, c.team_id, c.pipeline_source, c.created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm,
       length(c.push_title) AS title_len, length(c.push_text) AS text_len, length(c.headline) AS headline_len,
       (SELECT max(length(l)) FROM regexp_split_to_table(COALESCE(c.immersive_headline,''), E'\n') l) AS max_immersive_line,
       c.push_title, c.push_text
FROM content_items c JOIN teams t ON t.id=c.team_id
WHERE t.league_id=39 AND c.created_at >= :'pl_start'
  AND (length(c.push_title)>35 OR length(c.push_text)>90 OR length(c.headline)>160
       OR (SELECT max(length(l)) FROM regexp_split_to_table(COALESCE(c.immersive_headline,''), E'\n') l) > 22)
ORDER BY c.created_at;
\o

-- 22 Bannad register i push_title (samma regex som post_news.sh)
\o out/22_banned_register.csv
SELECT c.id, c.team_id, c.created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm, c.pushed_at IS NOT NULL AS pushed, c.push_title
FROM content_items c JOIN teams t ON t.id=c.team_id
WHERE t.league_id=39 AND c.created_at >= :'pl_start'
  AND c.push_title ~* '(big news|big drama|big swing|plot twist|plot thickens|wallet alert|quote drop|manager drama|strong reaction incoming|this just got worse|it just got worse|this is actually wild|^breaking|drama (at|before|incoming))'
ORDER BY c.created_at;
\o

-- 23 Opener-repetition: samma första 3 ord i push_title, samma lag, inom 72 h
\o out/23_opener_repetition_72h.csv
WITH x AS (
  SELECT c.id, c.team_id, c.created_at, c.push_title,
         lower(regexp_replace(array_to_string((regexp_split_to_array(trim(c.push_title),'\s+'))[1:3],' '),'[^a-z ]','','g')) AS opener
  FROM content_items c JOIN teams t ON t.id=c.team_id
  WHERE t.league_id=39 AND c.created_at >= :'pl_start' AND c.push_title IS NOT NULL
)
SELECT a.team_id, a.opener, a.id AS item_a, b.id AS item_b,
       a.created_at AT TIME ZONE 'Europe/Stockholm' AS a_sthlm, b.created_at AT TIME ZONE 'Europe/Stockholm' AS b_sthlm,
       a.push_title AS title_a, b.push_title AS title_b
FROM x a JOIN x b ON a.team_id=b.team_id AND a.opener=b.opener AND a.id<b.id
  AND b.created_at BETWEEN a.created_at AND a.created_at + interval '72 hours'
ORDER BY a.team_id, a.created_at;
\o

-- 24 Rubrik-dubbletter inom 72 h (samma lag; ≥5 gemensamma ord i rubriken)
\o out/24_headline_near_dupes_72h.csv
WITH w AS (
  SELECT c.id, c.team_id, c.created_at, c.headline, c.pushed_at IS NOT NULL AS pushed,
         (SELECT array_agg(DISTINCT lower(t2)) FROM regexp_split_to_table(regexp_replace(c.headline,'[^A-Za-z ]','','g'),'\s+') t2 WHERE length(t2)>3) AS words
  FROM content_items c JOIN teams t ON t.id=c.team_id
  WHERE t.league_id=39 AND c.created_at >= :'pl_start'
)
SELECT a.team_id, a.id AS item_a, b.id AS item_b, a.pushed AS pushed_a, b.pushed AS pushed_b,
       a.created_at AT TIME ZONE 'Europe/Stockholm' AS a_sthlm, b.created_at AT TIME ZONE 'Europe/Stockholm' AS b_sthlm,
       (SELECT count(*) FROM unnest(a.words) wa WHERE wa = ANY(b.words)) AS shared_words,
       a.headline AS headline_a, b.headline AS headline_b
FROM w a JOIN w b ON a.team_id=b.team_id AND a.id<b.id
  AND b.created_at BETWEEN a.created_at AND a.created_at + interval '72 hours'
WHERE (SELECT count(*) FROM unnest(a.words) wa WHERE wa = ANY(b.words)) >= 5
ORDER BY a.team_id, a.created_at;
\o

-- 25 Talking points: >1 "Ask him", TP1 som "Did you…", färre än 2 TP
\o out/25_talking_points_rules.csv
SELECT c.id, c.team_id, c.created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm,
       jsonb_array_length(c.talking_points) AS n_tp,
       (SELECT count(*) FROM jsonb_array_elements_text(c.talking_points) tp WHERE tp ~* '^\s*ask\s+him\b') AS n_ask_him,
       (c.talking_points->>0) ~* '^\s*did (you|he|she)\b' AS tp1_did_you,
       c.talking_points
FROM content_items c JOIN teams t ON t.id=c.team_id
WHERE t.league_id=39 AND c.created_at >= :'pl_start' AND jsonb_typeof(c.talking_points)='array'
  AND ((SELECT count(*) FROM jsonb_array_elements_text(c.talking_points) tp WHERE tp ~* '^\s*ask\s+him\b') > 1
       OR (c.talking_points->>0) ~* '^\s*did (you|he|she)\b'
       OR jsonb_array_length(c.talking_points) < 2)
ORDER BY c.created_at;
\o

-- 26 "Girl ref": analogi vs fallback, ordlängd (>16 ord bryter regeln)
\o out/26_analogy_stats.csv
SELECT c.team_id,
       count(*) AS items,
       count(*) FILTER (WHERE c.immersive_context IS NOT NULL AND c.immersive_context<>'') AS with_analogy,
       count(*) FILTER (WHERE (c.immersive_context IS NULL OR c.immersive_context='') AND c.immersive_context_fallback IS NOT NULL) AS fallback_only,
       count(*) FILTER (WHERE array_length(regexp_split_to_array(trim(c.immersive_context),'\s+'),1) > 16) AS analogy_over_16_words,
       count(*) FILTER (WHERE c.immersive_context IS NULL AND c.immersive_context_fallback IS NULL) AS neither
FROM content_items c JOIN teams t ON t.id=c.team_id
WHERE t.league_id=39 AND c.created_at >= :'pl_start' AND c.type IN ('news','matchday')
GROUP BY c.team_id ORDER BY items DESC;
\o

-- 27 Push vs feed-only per lag och vecka
\o out/27_push_vs_feedonly_weekly.csv
SELECT date_trunc('week', c.created_at AT TIME ZONE 'Europe/Stockholm')::date AS week_sthlm, c.team_id,
       count(*) AS items, count(*) FILTER (WHERE c.push_eligible) AS push_eligible,
       count(*) FILTER (WHERE c.pushed_at IS NOT NULL) AS pushed
FROM content_items c JOIN teams t ON t.id=c.team_id
WHERE t.league_id=39 AND t.is_active AND c.created_at >= :'pl_start'
GROUP BY 1,2 ORDER BY 1,2;
\o

-- 28 Kadens: sunday_brief per söndag, quiz per lördag, insider per dag, season-state-fas (PL)
\o out/28a_sunday_briefs.csv
SELECT (c.created_at AT TIME ZONE 'Europe/Stockholm')::date AS day_sthlm,
       to_char(c.created_at AT TIME ZONE 'Europe/Stockholm','Dy') AS dow, count(*) AS briefs,
       count(*) FILTER (WHERE c.pushed_at IS NOT NULL) AS pushed, string_agg(c.team_id, ',' ORDER BY c.team_id) AS teams
FROM content_items c JOIN teams t ON t.id=c.team_id
WHERE t.league_id=39 AND c.type='sunday_brief' AND c.created_at >= :'pl_start'
GROUP BY 1,2 ORDER BY 1;
\o

\o out/28b_quizzes.csv
SELECT (q.published_at AT TIME ZONE 'Europe/Stockholm')::date AS day_sthlm,
       to_char(q.published_at AT TIME ZONE 'Europe/Stockholm','Dy') AS dow, count(*) AS quizzes,
       string_agg(q.team_id, ',' ORDER BY q.team_id) AS teams
FROM saturday_quiz_items q JOIN teams t ON t.id=q.team_id
WHERE t.league_id=39 AND q.published_at >= :'pl_start'
GROUP BY 1,2 ORDER BY 1;
\o

\o out/28c_insider_daily.csv
SELECT (i.published_at AT TIME ZONE 'Europe/Stockholm')::date AS day_sthlm, count(*) AS items,
       count(DISTINCT i.team_id) AS teams, string_agg(DISTINCT i.type, ',') AS types
FROM team_insider_items i JOIN teams t ON t.id=i.team_id
WHERE t.league_id=39 AND i.published_at >= :'pl_start'
GROUP BY 1 ORDER BY 1;
\o

\o out/28d_season_state_pl.csv
SELECT s.team_id, s.phase, s.generated_at AT TIME ZONE 'Europe/Stockholm' AS generated_sthlm,
       s.next_fixture, left(s.summary, 200) AS summary_start
FROM team_season_state s JOIN teams t ON t.id=s.team_id
WHERE t.league_id=39 ORDER BY s.generated_at;
\o

-- 29 Everyone's talking (delad feed) sedan pl_start
\o out/29_everyone_talking.csv
SELECT c.id, c.team_id, c.type, c.created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm,
       c.everyone_talking_headline, c.headline
FROM content_items c WHERE c.everyone_talking AND c.created_at >= :'pl_start' ORDER BY c.created_at;
\o

-- 30 Konsekvenslagret: rader per lag/typ (A7 — förra säsongens rader blockerar nya?)
\o out/30_consequence_rows.csv
SELECT c.team_id, c.consequence_type, c.created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm,
       c.pushed_at IS NOT NULL AS pushed, c.headline
FROM content_items c WHERE c.consequence_type IS NOT NULL ORDER BY c.team_id, c.created_at;
\o

-- ============================================================================
-- B5 · VM-RETRO (lätt) — slutspel 28 jun → 20 jul
-- ============================================================================

-- 31 Slutspelsmatcher i match_status_state: status (AET/PEN), markörer, FT-latens
\o out/31_wc_knockout_matches.csv
SELECT fixture_id, home_team_id, away_team_id, status, home_goals, away_goals, elapsed,
       kickoff_time AT TIME ZONE 'Europe/Stockholm' AS kickoff_sthlm,
       fired_finished_at AT TIME ZONE 'Europe/Stockholm' AS fired_sthlm,
       EXTRACT(EPOCH FROM (fired_finished_at - kickoff_time))/60 AS fired_min_after_kickoff,
       briefs_fired,
       briefs_fired @> '["PREKICK_PUSH"]' AS prekick_pushed,
       briefs_fired @> '["HT_PUSH"]' AS ht_pushed,
       briefs_fired @> '["FT_PUSH"]' AS ft_pushed,
       la_started, la_ended, jsonb_array_length(COALESCE(goal_events,'[]'::jsonb)) AS n_goal_events
FROM match_status_state
WHERE league_id=1 AND kickoff_time >= :'wc_start' AND kickoff_time < :'wc_end'
ORDER BY kickoff_time;
\o

-- 32 VM-items i slutspelsfönstret (länder + world_championship)
\o out/32_wc_items.csv
SELECT c.id, c.team_id, t.entity_type, c.type, c.pipeline_source, c.consequence_type, c.push_eligible,
       c.created_at AT TIME ZONE 'Europe/Stockholm' AS created_sthlm,
       c.pushed_at AT TIME ZONE 'Europe/Stockholm' AS pushed_sthlm,
       EXTRACT(EPOCH FROM (c.pushed_at - c.created_at))/60 AS push_latency_min,
       c.preview_fixture_id, c.match_id, c.everyone_talking, c.headline, c.push_title, c.push_text,
       c.immersive_context, c.talking_points
FROM content_items c JOIN teams t ON t.id=c.team_id
WHERE t.entity_type IN ('country','tournament')
  AND c.created_at >= :'wc_start' AND c.created_at < :'wc_end'
ORDER BY c.created_at;
\o

-- 33 28 jun-bursten (manuella sunday_briefs): per minut
\o out/33_jun28_burst.csv
SELECT date_trunc('minute', c.created_at AT TIME ZONE 'Europe/Stockholm') AS minute_sthlm, count(*) AS items,
       count(*) FILTER (WHERE c.pushed_at IS NOT NULL) AS pushed,
       min(c.pushed_at) AT TIME ZONE 'Europe/Stockholm' AS first_push_sthlm,
       max(c.pushed_at) AT TIME ZONE 'Europe/Stockholm' AS last_push_sthlm
FROM content_items c JOIN teams t ON t.id=c.team_id
WHERE t.entity_type='country' AND c.type='sunday_brief'
  AND c.created_at >= '2026-06-27' AND c.created_at < '2026-06-30'
GROUP BY 1 ORDER BY 1;
\o

-- 34 Kvarvarande VM-leveranslogg (apns_send för länder) per dag
\o out/34_wc_apns_send_daily.csv
SELECT (ph.created_at AT TIME ZONE 'Europe/Stockholm')::date AS day_sthlm, ph.status, count(*)
FROM pipeline_health ph JOIN teams t ON t.id=ph.team_id
WHERE ph.stage='apns_send' AND t.entity_type='country' AND ph.created_at >= :'wc_start'
GROUP BY 1,2 ORDER BY 1,2;
\o

-- ============================================================================
-- PUBLIK (aggregat, ingen PII) — sätter volymer i proportion
-- ============================================================================

-- 35 get_insights() 45 dagar (JSON, en rad)
\pset format unaligned
\o out/35_insights_45d.json
SELECT get_insights(45);
\o
\pset format csv

-- 36 Följare per PL-lag (aktiva prod-tokens) — vem påverkas av A1/A2
\o out/36_pl_followers.csv
SELECT entity_id AS team_id, active_followers FROM v_audience_by_entity
WHERE entity_kind='team' ORDER BY active_followers DESC;
\o

\echo Klart. CSV:er ligger i out/. Zippa mappen och dela.
