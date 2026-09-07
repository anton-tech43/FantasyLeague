-- 088_content_reviews.sql
-- A weekly, durable record of what the app actually sent.
--
-- The 2026-09 World Cup review was a one-off that took a day and found that
-- 5% of cards met their own brief, that a whole code path had been shipping
-- half a card for six weeks, and that two consequence templates had never been
-- able to publish at all. None of that was visible from inside the pipeline,
-- because nothing looked back at the output as a body of work.
--
-- This table makes that look weekly and comparable. `metrics` is measured by
-- review_content.py — counting is the machine's job. `findings` and `actions`
-- are the routine's judgement, which is the part a script cannot do. Storing
-- both together is what lets the next review say "the bare-question rate went
-- from 42% to 6% after the guard landed", which is the only way to know the
-- work is working.

CREATE TABLE IF NOT EXISTS content_reviews (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Monday of the reviewed week, so a rerun overwrites rather than duplicates.
  week_of      date NOT NULL,
  generated_at timestamptz NOT NULL DEFAULT NOW(),
  window_days  integer NOT NULL DEFAULT 7,

  -- Deterministic counts from review_content.py. Same shape every week so the
  -- deltas are meaningful; see the script for the keys.
  metrics      jsonb NOT NULL DEFAULT '{}'::jsonb,

  -- What a reader concluded. Array of {severity, surface, finding, evidence}.
  -- severity: 'blocking' | 'degrading' | 'watch'.
  findings     jsonb NOT NULL DEFAULT '[]'::jsonb,

  -- What to change, ranked. Array of {change, where, why, size}. The point of
  -- the review is that this list gets shorter over time, not longer.
  actions      jsonb NOT NULL DEFAULT '[]'::jsonb,

  -- One honest paragraph. Read first, and the only part a human always reads.
  verdict      text,

  CONSTRAINT content_reviews_week_unique UNIQUE (week_of)
);

COMMENT ON TABLE content_reviews IS
  'Weekly review of everything the app showed a user. Written by the '
  'gd-content-review routine (Tuesdays 05:00). metrics = measured, '
  'findings/actions/verdict = judged.';

CREATE INDEX IF NOT EXISTS idx_content_reviews_week
  ON content_reviews (week_of DESC);

ALTER TABLE content_reviews ENABLE ROW LEVEL SECURITY;

-- Service role only. This is an internal quality record, not user content, and
-- it quotes copy that has not necessarily shipped.
DROP POLICY IF EXISTS content_reviews_service_all ON content_reviews;
CREATE POLICY content_reviews_service_all ON content_reviews
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

GRANT ALL ON content_reviews TO service_role;
