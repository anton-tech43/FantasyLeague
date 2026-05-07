-- 012_push_title.sql
-- Add push_title: a short conversational opener used as the APNs alert title.
--
-- Why we need it: previously the lock-screen title was just `team.short_name`
-- (e.g. "Forest"). That's identification, not communication — and on a feed
-- where every push for a given user is about the same team, the team name in
-- the title is dead space. Replacing it with a sister-voice opener
-- ("Heads up", "Bad mood loading", "Wallet alert", "Tomorrow's gossip")
-- turns the title into the conversation starter, with the body delivering
-- the mood + fact.
--
-- Together with push_text (migration 011), this means the lock-screen ping
-- reads like a text from her funny, smart big sister, not from a sports app.
--
-- Soft target ≤25 chars, hard limit 35. iOS bolds the title and shows it on
-- one line in lock-screen previews; longer = truncation.
--
-- Backfill: not needed. Old rows without push_title fall back to team
-- short_name (handled in apns-client.ts buildAPNsPayload).

ALTER TABLE content_items
ADD COLUMN push_title TEXT
CHECK (push_title IS NULL OR length(push_title) <= 35);

COMMENT ON COLUMN content_items.push_title IS
  'Conversational opener for the APNs alert title. ≤25 chars target, ≤35 hard limit. NULL for legacy rows; falls back to team short_name.';
