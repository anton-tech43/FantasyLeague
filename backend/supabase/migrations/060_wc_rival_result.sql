-- 060_wc_rival_result.sql
--
-- WC group-stage rival-result informational pushes.
--
-- At the full-time of a World Championship group game, the two NON-playing
-- teams in that group get a factual "rival result" content_item
-- (consequence_type = 'WC_RIVAL_RESULT', match_id = the triggering fixture
-- id, push_eligible = true). The push is informational only — it states
-- what happened ("Senegal beat Croatia in your group") and never derives
-- "what you need", which depends on a refreshed table + tiebreakers and
-- lives in-app. See match-watcher/index.ts + WC_GROUP_STAGE_DESIGN.md.
--
-- Unlike the one-time season events (TITLE_WON, RELEGATED, UCL_CLINCHED,
-- WC_KNOCKOUT_QUALIFIED, WC_GROUP_WON), a team receives a rival result
-- ONCE PER MATCHDAY, so it must NOT be blocked by the once-per-(team,type)
-- consequence index from migration 051. Idempotency for rival results comes
-- instead from the existing unique_matchday_content (team_id, match_id)
-- constraint (migration 001): at most one rival-result row per affected
-- team per triggering fixture.

DROP INDEX IF EXISTS idx_one_consequence_per_team_per_type;

CREATE UNIQUE INDEX idx_one_consequence_per_team_per_type
  ON content_items (team_id, consequence_type)
  WHERE consequence_type IS NOT NULL
    AND consequence_type <> 'WC_RIVAL_RESULT';

COMMENT ON INDEX idx_one_consequence_per_team_per_type IS
  'One row per team per one-time consequence event (title / relegation / '
  'European spot / WC group-won / WC knockout-qualified). Excludes '
  'WC_RIVAL_RESULT, which recurs each matchday and is deduped per '
  '(team_id, match_id) via unique_matchday_content instead. See migration 060.';
