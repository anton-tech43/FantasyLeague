-- 065_suppress_result_recap_push.sql
-- Stop the duplicate FT-result push.
--
-- match-watcher pushes a WC team's full-time result live (direct APNs). The
-- gd-news-wc ROUTINE then reposts the same result as a `news` item with
-- push_eligible=true, which notification-sender pushes hours later — so the
-- follower gets the result twice (Sweden: live FT ~03:58, routine recap pushed
-- 06:49). We suppress ONLY the result recap; all other routine WC news (squad,
-- build-up, manager) keeps pushing, and match-watcher's own edge_function rows
-- (the rival-result push, the matchday article) are untouched.
--
-- A recap is identified deterministically: a routine-sourced country `news`
-- item whose headline restates the scoreline of a match that finished for that
-- team in the last 18h (either scoreline order, so it's perspective-agnostic).

CREATE OR REPLACE FUNCTION suppress_wc_result_recap_push()
RETURNS trigger AS $$
BEGIN
  IF NEW.push_eligible IS TRUE
     AND NEW.pipeline_source = 'routine'
     AND NEW.type = 'news'
     AND NEW.headline IS NOT NULL
     AND EXISTS (SELECT 1 FROM teams t WHERE t.id = NEW.team_id AND t.entity_type = 'country')
     AND EXISTS (
       SELECT 1
       FROM match_status_state m
       WHERE (m.home_team_id = NEW.team_id OR m.away_team_id = NEW.team_id)
         AND m.status IN ('FT', 'AET', 'PEN')
         AND m.fired_finished_at > now() - interval '18 hours'
         AND m.home_goals IS NOT NULL
         AND m.away_goals IS NOT NULL
         AND (
           NEW.headline LIKE '%' || m.home_goals || '-' || m.away_goals || '%'
           OR NEW.headline LIKE '%' || m.away_goals || '-' || m.home_goals || '%'
         )
     )
  THEN
    NEW.push_eligible := false;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_suppress_wc_result_recap_push ON content_items;
CREATE TRIGGER trg_suppress_wc_result_recap_push
  BEFORE INSERT ON content_items
  FOR EACH ROW EXECUTE FUNCTION suppress_wc_result_recap_push();
