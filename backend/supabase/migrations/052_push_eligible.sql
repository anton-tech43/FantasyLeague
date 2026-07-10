-- 052_push_eligible.sql
--
-- Adds a per-row push-eligibility gate to content_items. When false,
-- the item publishes to the feed normally but notification-sender's
-- sweep skips the APNs push for that row.
--
-- Why this exists: a real push on 2026-05-22 read "He'll be absolutely
-- buzzing — Arsenal's captain Odegaard is heading to the World Cup
-- as Norway's captain…". For an Arsenal-ONLY follower, their captain
-- on international duty is fun-to-know trivia — it doesn't move
-- Arsenal's season — so the emotional "buzzing" opener was a tone
-- mismatch. The same story written for Norway followers (via the
-- separate gd-news-wc routine) IS team-impact and remains
-- push_eligible: true.
--
-- The PROMPT.md TEAM IMPACT gate decides which items get
-- push_eligible: false at write time. notification-sender filters on
-- this column to honour the gate. See IMPLEMENTATION_PROGRESS Lesson 76.
--
-- The column is NOT NULL DEFAULT TRUE so all existing rows and any
-- routines that don't know about the new field stay backward-
-- compatible — they still get the push they would have got before.

ALTER TABLE content_items
  ADD COLUMN push_eligible BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN content_items.push_eligible IS
  'When false, the item publishes to the feed but notification-sender '
  'skips the APNs push. Used for "fun-trivia" items (player on '
  'international duty for a country he doesn''t follow, off-pitch '
  'interviews, archive milestones) where a single-team follower has '
  'no strong emotional response. Default TRUE so the gate is '
  'OPT-OUT — routines that don''t set it ship the legacy behaviour. '
  'See PROMPT.md TEAM IMPACT gate + Lesson 76.';
