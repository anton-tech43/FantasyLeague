-- 046_starting_xi_content_type.sql
--
-- Adds 'starting_xi' to the content_items.type CHECK constraint. This is
-- the content type produced by the new gd-starting-xi cloud routine,
-- which fires at kickoff - 60min (scheduled by matchday-scheduler) and
-- writes a content_item with the lineup + a 1-2 sentence brief about
-- who's playing.
--
-- iOS renders it as a regular feed card (chip + headline + body) and
-- notification-sender pushes it the same way as news/matchday — no
-- tier-gating beyond the existing T1+ default for non-sunday_brief
-- content (notification-sender.minTierForType in V1.1).
--
-- Idempotent: DROPS the existing constraint first so re-applying the
-- migration in dev doesn't trip an "already exists" error.

ALTER TABLE content_items DROP CONSTRAINT IF EXISTS content_items_type_check;
ALTER TABLE content_items ADD CONSTRAINT content_items_type_check
    CHECK (type IN ('news', 'matchday', 'sunday_brief', 'starting_xi'));
