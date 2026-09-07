-- 092: My Turn content delivery.
--
-- My Turn (Say This / Lingo / Quiz / Drills) ships four JSON files in the app
-- bundle so it works offline. This table lets a newer version of any file
-- reach the app without an App Store release: at launch the app reads the
-- manifest (module, content_version), downloads what is newer than what it
-- holds, caches it locally and keeps the previous version for rollback.
--
-- Publish with tools/myturn/publish_content.sh, which runs the validator first.
-- A failed fetch is not an error for the user — the app keeps what it has.

CREATE TABLE IF NOT EXISTS my_turn_content (
  module          text PRIMARY KEY CHECK (module IN ('saythis', 'lingo', 'quiz', 'drills')),
  content_version text NOT NULL,
  body            jsonb NOT NULL,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE my_turn_content ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS my_turn_content_public_read ON my_turn_content;
CREATE POLICY my_turn_content_public_read ON my_turn_content
  FOR SELECT USING (true);

COMMENT ON TABLE my_turn_content IS
  'My Turn module content (static, versioned). App fetches newer content_version than its bundle/cache. See tools/myturn/.';
