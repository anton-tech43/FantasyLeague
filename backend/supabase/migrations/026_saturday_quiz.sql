-- 026_saturday_quiz.sql
-- v1.1 Saturday Quiz Card (V1.1_FEATURE_BUNDLE.md task C3)
--
-- A 3-question multiple-choice quiz generated weekly by the gd-saturday-quiz
-- cloud routine (cron 0 7 * * 6 — Saturday 07:00 UTC). One row per team per
-- week. iOS reads the freshest row via the quiz-current Edge Function which
-- gates on a 36-hour window (Saturday 07:00 UTC through Sunday 19:00 UTC) so
-- the card only renders during weekend match-stress hours, never midweek.
-- T3+ tier-gated client-side (FeedView).
--
-- Difficulty calibration target: a reader who's been using the app gets 3/3;
-- random guessing scores ~1.5/3. Questions are about her team's upcoming
-- weekend — form, who's injured, opponent, what's at stake — so the prep
-- her week did pays off when she shows him.

CREATE TABLE saturday_quiz_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id         TEXT NOT NULL REFERENCES teams(id),
    -- Optional API-Football fixture id for the weekend's match. Nullable
    -- because the routine may run before a fixture is finalised or for a
    -- team without a PL fixture that weekend (FA Cup weekend etc).
    match_id        TEXT NULL,
    -- Short label shown on the collapsed pill: e.g., "Liverpool weekend".
    -- 6-40 chars enforced by post_quiz.sh.
    headline        TEXT NOT NULL,
    -- JSONB array of exactly 3 question objects. Shape:
    -- [{
    --    "q": "Who do they play this Saturday?",
    --    "options": ["Arsenal", "Liverpool", "Spurs"],
    --    "correct": 1,
    --    "explainer": "Liverpool are the opponent and they're sitting third in the table."
    --  }, ...]
    -- correct is a 0|1|2 index into options. JSONB (not JSON) so we can
    -- query/index option content in future if we need to. No CHECK on
    -- shape — bash validators in post_quiz.sh own the schema guard.
    questions       JSONB NOT NULL,
    -- Template the iOS ShareLink fills in with the score, e.g.
    -- "GoalDigger Saturday Quiz: {score}/3 — Liverpool weekend"
    share_template  TEXT NOT NULL,
    published_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Composite index serves the read endpoint: "give me the freshest row for
-- this team in the last 36 hours." Descending by published_at means the
-- LIMIT 1 lookup is a single index seek.
CREATE INDEX idx_saturday_quiz_team_published
    ON saturday_quiz_items (team_id, published_at DESC);

-- RLS: read-only public access, writes only via service role. Same pattern
-- as live_match_briefs / team_insider_items / team_season_state.
ALTER TABLE saturday_quiz_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "saturday_quiz_items public read"
    ON saturday_quiz_items
    FOR SELECT
    USING (true);
