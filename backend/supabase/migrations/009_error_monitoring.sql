-- 009_error_monitoring.sql
-- Developer-facing error monitoring: log client failures + push alerts
-- to registered developer devices.

-- ============================================================
-- 1. client_errors — log of failures reported by the iOS client
-- ============================================================
CREATE TABLE client_errors (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    error_type    TEXT NOT NULL,        -- 'fetch_feed', 'decode', 'empty_feed', 'fetch_item', 'fetch_team_page', etc.
    message       TEXT NOT NULL,
    request_path  TEXT,
    team_id       TEXT,                 -- nullable; populated when applicable
    app_version   TEXT,
    device_model  TEXT,
    os_version    TEXT,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    alerted_at    TIMESTAMPTZ           -- non-null once we've sent a push for this row
);

CREATE INDEX idx_client_errors_recent ON client_errors(created_at DESC);
CREATE INDEX idx_client_errors_unalerted ON client_errors(error_type, created_at)
    WHERE alerted_at IS NULL;

-- ============================================================
-- 2. dev_alert_devices — APNs tokens that should receive
--    error-monitoring push notifications. Separate from
--    device_tokens because dev alerts aren't tied to a team.
-- ============================================================
CREATE TABLE dev_alert_devices (
    apns_token     TEXT PRIMARY KEY
                   CONSTRAINT valid_apns_token CHECK (apns_token ~ '^[a-fA-F0-9]{64}$'),
    label          TEXT NOT NULL,        -- e.g. 'anton-iphone' for human reference
    is_active      BOOLEAN DEFAULT true,
    registered_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. RLS — service role only. anon must not read errors or
--    register/discover dev devices.
-- ============================================================
ALTER TABLE client_errors ENABLE ROW LEVEL SECURITY;
ALTER TABLE dev_alert_devices ENABLE ROW LEVEL SECURITY;

-- iOS posts errors via the client-error-alert edge function (service-role auth),
-- not directly via REST, so no anon INSERT policy is needed.
-- Service role bypasses RLS.

CREATE POLICY client_errors_service ON client_errors FOR ALL TO service_role USING (true);
CREATE POLICY dev_alert_devices_service ON dev_alert_devices FOR ALL TO service_role USING (true);
