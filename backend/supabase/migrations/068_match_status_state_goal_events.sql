-- 068_match_status_state_goal_events.sql
-- Live box "who scored, what minute". match-watcher already fetches
-- /fixtures/events on a detected goal to build the push scorer line, then
-- discards it. Persist the full parsed list here (tagged home/away) so
-- live-brief-current can return a scorers[] for the in-app live card without
-- any extra API-Football call on the read path.
--
-- Shape (StoredGoalEvent[] from _shared/goal-push.ts):
--   [{ "side": "home"|"away", "player": string|null, "minute": int|null,
--      "extra": int|null, "isOwnGoal": bool, "isPenalty": bool }, ...]
--
-- Nullable, no default: a row with no observed goals simply has no column
-- value, and match-watcher only writes it on a tick where it fetched events
-- (so a quiet tick never clobbers a populated list).

ALTER TABLE match_status_state
  ADD COLUMN IF NOT EXISTS goal_events JSONB;
