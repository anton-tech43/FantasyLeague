-- 123_team_page_prose_history.sql
--
-- On 2026-09-30 the "ones to know" card was found naming players who were not
-- playing — across the 20 active clubs, 20 of 60 picks sat outside their own
-- squad's top fifteen by minutes. The obvious diagnostic question was "did last
-- Monday's card say the same thing?", and it could not be answered: `team_pages`
-- holds `team_id`, `content`, `updated_at` and nothing else, so the previous
-- value of every card is gone the instant it is overwritten. The conclusion that
-- a weekly rewrite had been returning the same three players every Monday had to
-- be reasoned out rather than read off.
--
-- This records the prose so that question becomes a query, and so the next two
-- weeks can measure how often the prose actually changes — and goes wrong —
-- between Mondays.
--
-- WHY ONLY THE PROSE, AND NOT `content`
-- `team-page-generator`'s dynamic_only pass rewrites every row every two hours
-- from 06:00, roughly 600 UPDATEs a day across 71 rows of ~14 kB each, 71% of it
-- TOASTed JSONB. One history row per write would be ~8 MB/day and ~240 MB over
-- this window — the same order as `raw_fetch_logs` when it drained the Disk IO
-- budget in June (Lesson 84). Nearly all of that churn is numbers: table
-- position, form, the next fixture. The prose measures 1,609 bytes per club,
-- 31 kB for all twenty, and changes about weekly. Scoped to the prose this table
-- is a few hundred kilobytes.
--
-- `ones_to_know.opponent` is deliberately excluded: it is rebuilt every refresh
-- from the opponent's own page, so it is derived data rather than prose we wrote,
-- and including it would reintroduce exactly the churn this scope avoids.
--
-- WHY A TRIGGER, AND WHY IT COMPARES CONTENT RATHER THAN `updated_at`
-- Four writers reach this table and they do not agree on `updated_at`:
-- team-page-generator's full and dynamic paths set it, `match-watcher`'s
-- post-match card does NOT (match-watcher/index.ts:613), three UPDATEs in
-- migration 091 do not either, and `post_team_page.sh` PATCHes from outside this
-- repo entirely over PostgREST. Only a trigger sees all four, and only a content
-- comparison survives the writers that leave the timestamp alone.

-- CORRECTED 2026-10-02 after an adversarial review. Three claims below are
-- wrong and migration 124 carries the fixes; they are left in place because
-- this file is the record of what ran.
--   * The self-check at the bottom cannot fail for the bug it guards against.
--     It counts rows and never reads them, so a trigger recording NEW instead
--     of OLD passes it. 124 has the assertion it should have had.
--   * "03:30 and 03:35 are free" is false — `content-audit-nightly` has been at
--     30 3 since migration 059. 124 moves these to 03:40 and 03:45.
--   * match-watcher is named below as a writer this trigger must catch. It
--     writes only `cards.post_match`, which is outside the prose scope, so it
--     can never produce a row. The argument holds for post_team_page.sh's
--     external PATCH, which is the real reason a trigger was needed.
--   * The "dynamic writes produce no history" framing is slightly too broad:
--     `updateWcDynamicFields` sets `cards.manager.summary` on every WC refresh,
--     which IS in scope. Harmless only because COACH_OVERRIDES are constants
--     and the 48 countries are inactive.
--   * The autovacuum note calls this table update-churn-dominated. It is not
--     (n_tup_upd = 0); the dead tuples come from the nightly DELETE. The
--     settings are right, the reason given is not.

BEGIN;

CREATE TABLE IF NOT EXISTS public.team_page_prose_history (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id     text NOT NULL REFERENCES public.teams(id),
  prose       jsonb NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.team_page_prose_history IS
  'Previous value of the routine-written prose on a team page, kept 30 days. '
  'Written by a trigger on team_pages, swept nightly at 03:30, vacuumed at 03:35. '
  'Scoped to the prose because the full content churns every two hours.';

-- Reads are "this club, newest first" and "everything in the last N days".
CREATE INDEX IF NOT EXISTS idx_team_page_prose_history_team
  ON public.team_page_prose_history (team_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_team_page_prose_history_recent
  ON public.team_page_prose_history (recorded_at DESC);

ALTER TABLE public.team_page_prose_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS team_page_prose_history_service ON public.team_page_prose_history;
CREATE POLICY team_page_prose_history_service ON public.team_page_prose_history
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- An append-only table swept daily is update-churn-dominated, the shape that
-- starved pg_cron in September. Same tuning migration 104 gave pipeline_health.
ALTER TABLE public.team_page_prose_history SET (
  autovacuum_vacuum_scale_factor  = 0.02,
  autovacuum_analyze_scale_factor = 0.02
);

-- The prose, and only the prose. One definition, used by the trigger and by
-- anything reading the history, so the two can never drift apart.
CREATE OR REPLACE FUNCTION public.team_page_prose(content jsonb)
  RETURNS jsonb
  LANGUAGE sql
  IMMUTABLE
  SET search_path TO ''
AS $function$
  SELECT jsonb_strip_nulls(jsonb_build_object(
    'players',       content->'cards'->'ones_to_know'->'players',
    'talking_point', content->'cards'->'ones_to_know'->'talking_point',
    'season',        content->'cards'->'season'->'summary',
    'form',          content->'cards'->'form'->'form_summary',
    'manager',       content->'cards'->'manager'->'summary'
  ))
$function$;

REVOKE EXECUTE ON FUNCTION public.team_page_prose(jsonb) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.record_team_page_prose()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
DECLARE
  prior_prose jsonb;
BEGIN
  -- Named `prior_prose`, never `old`: that is a reserved trigger variable and
  -- the reference fails at runtime, on every write, not at creation — which is
  -- how migrations 114 and 117 each applied clean and left a broken table.
  prior_prose := public.team_page_prose(OLD.content);

  IF prior_prose IS DISTINCT FROM public.team_page_prose(NEW.content) THEN
    INSERT INTO public.team_page_prose_history (team_id, prose)
    VALUES (OLD.team_id, prior_prose);
  END IF;

  RETURN NEW;
END
$$;

REVOKE EXECUTE ON FUNCTION public.record_team_page_prose() FROM PUBLIC, anon, authenticated;

-- Column-scoped: a bare `updated_at` touch must not wake the trigger at all.
DROP TRIGGER IF EXISTS team_page_prose_history_trg ON public.team_pages;
CREATE TRIGGER team_page_prose_history_trg
  BEFORE UPDATE OF content ON public.team_pages
  FOR EACH ROW EXECUTE FUNCTION public.record_team_page_prose();

COMMIT;

-- ============================================================
-- Retention: thirty days, swept and vacuumed as separate jobs
-- ============================================================
-- Two constraints, both learned the hard way in migration 104:
--   * VACUUM cannot run inside a transaction block and pg_cron wraps a
--     multi-statement command in one, so the vacuum is its own job holding
--     exactly one statement, five minutes after the delete.
--   * Plain VACUUM, never FULL — this table has a live writer and FULL takes
--     an ACCESS EXCLUSIVE lock.
-- 03:00, 03:15, 03:20 and 03:25 are taken by the existing sweeps; 03:30 and
-- 03:35 are free.

SELECT cron.unschedule('team_page_prose_history_retention_sweep')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'team_page_prose_history_retention_sweep');

SELECT cron.schedule(
  'team_page_prose_history_retention_sweep',
  '30 3 * * *',
  $$DELETE FROM public.team_page_prose_history WHERE recorded_at < NOW() - INTERVAL '30 days'$$
);

SELECT cron.unschedule('team_page_prose_history_vacuum')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'team_page_prose_history_vacuum');

SELECT cron.schedule(
  'team_page_prose_history_vacuum',
  '35 3 * * *',
  $$VACUUM (ANALYZE) public.team_page_prose_history$$
);

-- ============================================================
-- Self-check, in a transaction that is always rolled back
-- ============================================================
-- Proves the two properties the design depends on: a prose change is recorded,
-- and the ~600 numbers-only writes a day are not. The probe mutates a real row,
-- so it runs inside an explicit transaction ending in ROLLBACK — a trigger
-- fires within its transaction like any other statement, so nothing here needs
-- to be committed to be observed. If a check raises, the transaction aborts and
-- the probe is undone by that too.

BEGIN;

DO $$
DECLARE
  before_n      int;
  after_prose   int;
  after_numbers int;
  sample        text;
BEGIN
  SELECT team_id INTO sample FROM public.team_pages LIMIT 1;
  SELECT count(*) INTO before_n FROM public.team_page_prose_history;

  UPDATE public.team_pages
     SET content = jsonb_set(content, '{cards,season,summary}', '"migration 123 probe"')
   WHERE team_id = sample;
  SELECT count(*) INTO after_prose FROM public.team_page_prose_history;
  IF after_prose <> before_n + 1 THEN
    RAISE EXCEPTION 'migration 123: a prose change recorded % rows, expected 1',
                    after_prose - before_n;
  END IF;

  -- The whole scope argument in one assertion.
  UPDATE public.team_pages
     SET content = jsonb_set(content, '{cards,form,league_position}', '99')
   WHERE team_id = sample;
  SELECT count(*) INTO after_numbers FROM public.team_page_prose_history;
  IF after_numbers <> after_prose THEN
    RAISE EXCEPTION 'migration 123: a numbers-only write recorded % rows, expected 0',
                    after_numbers - after_prose;
  END IF;

  RAISE NOTICE 'migration 123 self-check passed on %: prose recorded, numbers ignored', sample;
END $$;

ROLLBACK;

-- Verification (expect: no probe text anywhere, two jobs, an empty history):
--   SELECT count(*) FROM team_pages WHERE content::text LIKE '%migration 123 probe%';  -- 0
--   SELECT jobname, schedule FROM cron.job WHERE jobname LIKE 'team_page_prose_history%';  -- 2 rows
--   SELECT count(*) FROM team_page_prose_history;  -- 0 until the next real prose write
