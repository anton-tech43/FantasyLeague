-- 124_review_fixes_for_122_and_123.sql
--
-- An adversarial review of migrations 122 and 123 (2026-10-02) found six things
-- worth fixing. The migrations themselves are left as the record of what ran;
-- this file is the correction.
--
-- The finding that mattered most: **123's self-check could not fail for the bug
-- it was written to catch.** The reviewer replaced `record_team_page_prose()`
-- with a version recording NEW instead of OLD — the one inversion that would
-- make the whole table useless — and 123's self-check still reported success,
-- because it only counted rows and never looked at what was in them. The live
-- trigger is correct (verified: a probe UPDATE records the pre-update value),
-- but it was correct by luck of writing rather than by anything that checked.
--
-- That is the same defect this session spent two days removing from other
-- people's checks, so it gets the same treatment here.

BEGIN;

-- ============================================================
-- 1. The two names migration 122 repaired still look untouched
-- ============================================================
-- 122 rewrote `J.  McGinn` and `Ilyas  Ansah` without setting `updated_at`,
-- where migration 110 had done the same repair correctly (110:102). Their rows
-- still carry timestamps from 8 and 10 September, so anything treating that
-- column as "when this row last changed" — the staleness read in the
-- stale-data-audit skill, any incremental consumer — is being told a name that
-- changed on 30 September has not moved in three weeks.
--
-- Set to now() rather than to the repair time: the exact moment is not
-- recoverable, and the only direction that is safe for a staleness check is
-- the one that cannot make a changed row look older than it is.
UPDATE public.players
   SET updated_at = now()
 WHERE name IN ('J. McGinn', 'Ilyas Ansah')
   AND updated_at < '2026-09-30'::timestamptz;

-- ============================================================
-- 2. Nothing is actually free at 03:30
-- ============================================================
-- 123 chose 03:30 and 03:35 on the stated grounds that "03:00, 03:15, 03:20
-- and 03:25 are taken by the existing sweeps; 03:30 and 03:35 are free". It
-- checked four slots and missed `content-audit-nightly`, which has been at
-- 30 3 * * * since migration 059. Both have run side by side without incident
-- — content-audit is a non-blocking net.http_post — so this is the reasoning
-- being wrong rather than the system being broken. But the staggering
-- convention exists so that nobody has to check, and the next person will
-- read that comment and trust it.
SELECT cron.unschedule('team_page_prose_history_retention_sweep')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'team_page_prose_history_retention_sweep');

SELECT cron.schedule(
  'team_page_prose_history_retention_sweep',
  '40 3 * * *',
  $$DELETE FROM public.team_page_prose_history WHERE recorded_at < NOW() - INTERVAL '30 days'$$
);

SELECT cron.unschedule('team_page_prose_history_vacuum')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'team_page_prose_history_vacuum');

SELECT cron.schedule(
  'team_page_prose_history_vacuum',
  '45 3 * * *',
  $$VACUUM (ANALYZE) public.team_page_prose_history$$
);

-- ============================================================
-- 3. Close the table the way the functions were closed
-- ============================================================
-- 123 revoked EXECUTE on both its functions and then left `anon` holding the
-- SELECT that Supabase's default privileges grant on every new table in
-- `public`. RLS is what actually stops a read today (the only policy is
-- service_role, and a probe as anon returns zero rows), so this is
-- defence-in-depth — but the same file was careful about exactly this for
-- functions, and the habit is the point. See CLAUDE.md on why `FROM PUBLIC`
-- alone never closes anything here.
REVOKE ALL ON TABLE public.team_page_prose_history FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 4. Say what the functions do, where \df+ will show it
-- ============================================================
-- `CREATE OR REPLACE` preserves the old COMMENT, so decode_feed_entities still
-- described only the HTML-entity half of its job and said nothing about the
-- whitespace squeeze that migration 122 exists to add. 123's two functions had
-- no comment at all.
COMMENT ON FUNCTION public.decode_feed_entities(text) IS
  'Normalise a value from an upstream feed: undo API-Football''s HTML escaping '
  '(mig 110, &apos; &#39; &quot; &lt; &amp;), then collapse internal whitespace '
  'runs to one space and trim (mig 122, after `J.  McGinn` broke a name join). '
  'Note \s also matches U+00A0, so a non-breaking space becomes an ASCII space.';

COMMENT ON FUNCTION public.team_page_prose(jsonb) IS
  'The routine-written prose on a team page, and nothing else: ones_to_know '
  'players and talking_point, season summary, form summary, manager summary. '
  'Deliberately excludes ones_to_know.opponent, which the dynamic pass rebuilds '
  'every two hours from the opponent''s own page. One definition shared by the '
  'history trigger and anything reading the history, so the two cannot drift.';

COMMENT ON FUNCTION public.record_team_page_prose() IS
  'Records the PREVIOUS prose on team_pages when and only when the prose '
  'changes. Compares content rather than updated_at, because match-watcher and '
  'three UPDATEs in migration 091 write the row without touching the timestamp.';

COMMIT;

-- ============================================================
-- 5. The self-check 123 should have had
-- ============================================================
-- Asserts the VALUE, not the row count. Had this existed, the reviewer's
-- OLD-to-NEW inversion would have failed the migration instead of passing it.
-- Still a post-deploy smoke test rather than a gate — it runs after the DDL is
-- committed, which is 123's other structural weakness and is not fixable
-- without re-applying that migration — but it is now a test that can fail.
--
-- Probes a real Premier League club. 123 used `LIMIT 1` with no ORDER BY and
-- got `algeria`, a dormant country page that none of the four writers touches.

BEGIN;

DO $$
DECLARE
  prose_before jsonb;
  prose_recorded jsonb;
  rows_from_numbers int;
  rows_before int;
BEGIN
  SELECT public.team_page_prose(content) INTO prose_before
    FROM public.team_pages WHERE team_id = 'arsenal';

  UPDATE public.team_pages
     SET content = jsonb_set(content, '{cards,season,summary}', '"migration 124 probe"')
   WHERE team_id = 'arsenal';

  SELECT prose INTO prose_recorded FROM public.team_page_prose_history
   WHERE team_id = 'arsenal' ORDER BY recorded_at DESC LIMIT 1;

  -- The assertion 123 was missing. A trigger recording NEW passes 123 and
  -- fails here.
  IF prose_recorded IS DISTINCT FROM prose_before THEN
    RAISE EXCEPTION 'migration 124: history recorded the wrong value. expected the pre-update prose, got %',
                    left(prose_recorded->>'season', 60);
  END IF;

  -- And the scope claim, probed on a field that is actually inside a
  -- prose-scoped card rather than one the function provably never reads.
  -- 123 probed `cards.form.league_position`, which `team_page_prose()` does
  -- not look at, so that assertion could not have failed however the trigger
  -- was written.
  SELECT count(*) INTO rows_before FROM public.team_page_prose_history;
  UPDATE public.team_pages
     SET content = jsonb_set(content, '{cards,ones_to_know,opponent}', '{"team_name":"Probe FC"}')
   WHERE team_id = 'arsenal';
  SELECT count(*) INTO rows_from_numbers FROM public.team_page_prose_history;
  IF rows_from_numbers <> rows_before THEN
    RAISE EXCEPTION 'migration 124: ones_to_know.opponent produced % history rows, expected 0 — it is rebuilt every two hours',
                    rows_from_numbers - rows_before;
  END IF;

  RAISE NOTICE 'migration 124 self-check passed: history records OLD, and the two-hourly opponent rebuild is excluded';
END $$;

ROLLBACK;

-- Verification (expect: no probe text, jobs at 03:40/03:45, anon shut out):
--   SELECT count(*) FROM team_pages WHERE content::text LIKE '%migration 124 probe%';           -- 0
--   SELECT jobname, schedule FROM cron.job WHERE jobname LIKE 'team_page_prose_history%';       -- 40 3, 45 3
--   SELECT has_table_privilege('anon','public.team_page_prose_history','SELECT');               -- f
--   SELECT updated_at FROM players WHERE name IN ('J. McGinn','Ilyas Ansah');                   -- both today
--
-- Answering "did the prose change this week?", which the history table cannot
-- answer alone — a club whose rewrite produced identical prose records no row,
-- and that is indistinguishable from a club whose routine never ran. Join
-- `last_routine_run`, which post_team_page.sh stamps unconditionally, and the
-- two cases separate:
--   SELECT tp.team_id,
--          (tp.content->>'last_routine_run')::timestamptz AS routine_wrote,
--          (SELECT count(*) FROM team_page_prose_history h
--            WHERE h.team_id = tp.team_id
--              AND h.recorded_at > (tp.content->>'last_routine_run')::timestamptz - interval '10 min')
--            AS prose_changed
--     FROM team_pages tp JOIN teams t ON t.id = tp.team_id
--    WHERE t.entity_type = 'club' AND t.is_active;
-- routine_wrote recent AND prose_changed = 0 means the rewrite returned the
-- same words, which is exactly the finding this table was built to measure.
