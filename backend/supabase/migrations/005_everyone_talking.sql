-- 005_everyone_talking.sql
-- Goal Digger — Everyone's Talking About + Immersive Feed + Analogy System
-- Adds: cross-team feed columns, immersive card columns, analogy review pipeline,
--        analogy_rejections monitoring table, auto-publish cron, monitoring view

-- ============================================================
-- EVERYONE'S TALKING ABOUT — cross-team feed columns
-- ============================================================

ALTER TABLE content_items ADD COLUMN everyone_talking BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE content_items ADD COLUMN everyone_talking_headline TEXT;
ALTER TABLE content_items ADD COLUMN everyone_talking_body TEXT;
ALTER TABLE content_items ADD COLUMN everyone_talking_talking_points JSONB;
ALTER TABLE content_items ADD COLUMN worth_knowing BOOLEAN NOT NULL DEFAULT false;

-- Partial index for fast everyone feed queries
CREATE INDEX idx_content_everyone_talking
    ON content_items(published_at DESC)
    WHERE status = 'published' AND everyone_talking = true;

-- ============================================================
-- IMMERSIVE CARD — headline + analogy columns
-- ============================================================

ALTER TABLE content_items ADD COLUMN immersive_headline TEXT;
ALTER TABLE content_items ADD COLUMN immersive_context TEXT;
ALTER TABLE content_items ADD COLUMN immersive_context_fallback TEXT;

-- ============================================================
-- ANALOGY REVIEW PIPELINE — review state columns
-- ============================================================

ALTER TABLE content_items ADD COLUMN analogy_reviewed BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE content_items ADD COLUMN analogy_approved BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE content_items ADD COLUMN analogy_auto_published BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE content_items ADD COLUMN analogy_critic_score JSONB;

-- ============================================================
-- ANALOGY REJECTIONS — monitoring table for tuning prompts
-- ============================================================

CREATE TABLE analogy_rejections (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_item_id   UUID REFERENCES content_items(id),
    rejected_analogy  TEXT NOT NULL,
    critic_scores     JSONB,
    critic_reason     TEXT,
    rejected_at       TIMESTAMPTZ DEFAULT NOW(),
    rejected_by       TEXT DEFAULT 'ai_critic'
        CHECK (rejected_by IN ('ai_critic', 'human'))
);

-- ============================================================
-- AUTO-PUBLISH CRON — fallback for unreviewed analogies after 4h
-- Uses immersive_context_fallback, never the unreviewed analogy
-- ============================================================

SELECT cron.schedule(
    'analogy-auto-publish',
    '*/30 * * * *',
    $$UPDATE content_items
    SET analogy_reviewed = true,
        analogy_approved = false,
        analogy_auto_published = true
    WHERE analogy_reviewed = false
      AND created_at < NOW() - INTERVAL '4 hours'
      AND immersive_context_fallback IS NOT NULL$$
);

-- ============================================================
-- MONITORING VIEW — daily volume tracking
-- ============================================================

CREATE OR REPLACE VIEW everyone_talking_daily AS
SELECT
    date_trunc('day', created_at) AS day,
    count(*) FILTER (WHERE everyone_talking = true) AS everyone_count,
    count(*) FILTER (WHERE worth_knowing = true) AS worth_knowing_count,
    count(*) FILTER (WHERE analogy_auto_published = true) AS auto_published_count,
    count(*) FILTER (WHERE analogy_approved = true) AS analogy_approved_count
FROM content_items
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1 DESC;
