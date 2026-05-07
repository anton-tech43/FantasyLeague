-- 010_apns_environment.sql
-- Per-token APNs environment so the same backend can push to both sandbox
-- (DEBUG iOS builds) and production (App Store / TestFlight builds) without
-- needing to flip a global flag at launch.
--
-- iOS reports its build environment when registering. Backend looks up the
-- env per token and pushes to the correct Apple endpoint.

ALTER TABLE device_tokens
    ADD COLUMN apns_environment TEXT NOT NULL DEFAULT 'development'
    CHECK (apns_environment IN ('development', 'production'));

ALTER TABLE dev_alert_devices
    ADD COLUMN apns_environment TEXT NOT NULL DEFAULT 'development'
    CHECK (apns_environment IN ('development', 'production'));
