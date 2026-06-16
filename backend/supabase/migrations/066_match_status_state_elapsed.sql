-- 066_match_status_state_elapsed.sql
-- Store the live match minute (API-Football fixture.status.elapsed) so the
-- in-app live card (live-brief-current) and the Live Activity can show
-- "63' / 90". Nullable: NS / HT / FT / pre-kickoff rows have no meaningful
-- elapsed.
--
-- This reverses the earlier "deliberately NOT the minute" choice for the Live
-- Activity badge (see wc-countries.ts:wcStatusLabel) at the user's explicit
-- request. The trade-off that note guarded against — an extra silent LA update
-- push per minute — is negligible at current device counts; revisit if the
-- user base grows large.

ALTER TABLE match_status_state ADD COLUMN IF NOT EXISTS elapsed INTEGER;
