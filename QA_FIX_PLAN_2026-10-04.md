# QA fix plan, 2026-10-04 (from QA_REPORT_2026-10-04.md)

Target: iOS 2.3 (build 15) + backend. Each item is verified before it is fixed; items found not real are marked so.

## Prod operations (owner: Anton, the agent was blocked by the permission classifier)
- C1 rotate `CRON_AUTH_KEY` + Vault `cron_service_key` together (`scripts/rotate-cron-key.sh`), then update `backend/.env` SUPABASE_SERVICE_ROLE_KEY (it holds the same value for manual ops curl).
- H1 `supabase functions delete health-check backfill-analogies push-probe`.
- Rotate the DB password (it was printed into a session transcript); rotate the legacy JWT secret in the dashboard.
- Register a dev device in `dev_alert_devices` so alerts reach someone.
- Publish the corrected privacy policy text (`docs/PRIVACY_POLICY_DRAFT.md`) and give it its own URL.

## Backend functions (agent BE-fn)
QA-03 dead-token logic, QA-04 pagination + chunked deactivate, QA-06 fallback, QA-08 claim-before-send, QA-11 per-fixture isolation, QA-12 inactive-club fires, QA-14 constant-time gate + shared gate in register-dev-device/diagnose-matchday, QA-15 drop unused transfers fetch, QA-18 derby double reminder, F3 delete-my-data logging, BUILD-1 type errors.

## Database migration 129 (agent BE-sql)
QA-05 prep cron hours, QA-09/QA-16 retention + stale-token purges, QA-10 RPC payload caps + rate limits (+ LA tokens) + created_at index, QA-17/F4 revoke SELECT on RLS-only tables.

## iOS lifecycle, privacy, settings (agent iOS-A)
NEW-1 token refresh, NEW-2 PrivacyInfo.xcprivacy, NEW-5 empty club list, NEW-6 `.id(teamId)`, NEW-7 Delete My Data completeness, NEW-10 Live Activity gating/stale/end, H6 first-run feed context, ONB-4 notDetermined, NEW-17 calendar revoked, NEW-14 country-flag leaks, settings a11y labels, Info.plist pronoun.

## iOS onboarding, accessibility, theme (agent iOS-B)
NEW-3 My Turn VoiceOver, NEW-4 onboarding scroll + Dynamic Type, H5 His Team truncation at large text, NEW-12 a11y traits + contrast, toggle/placeholder contrast, NEW-24 copy.

## iOS feed, content, quiz (agent iOS-C)
NEW-13 feed races/dupes/stale, iOS-3 unread counts, NEW-8 "World Cup" in bundled content + validator, NEW-15 en dashes, NEW-16 remote content validation, quiz answer capital, SaturdayQuizCard guard, NEW-18 date locale, NEW-19 audio session.

## Content (main session)
Palace "Europa League group" item corrected; routine prompt rule: UEFA competitions have a league phase (no groups) and no unsourced fan claims.

## Deferred, with reason
- NEW-9 pronoun rule across ~590 My Turn lines: a content rewrite, not a mechanical swap (verb agreement breaks). Partner voice is the default and correct today.
- H9 App Attest/DeviceCheck for registration: payload caps + rate limits land now; attestation is a larger project.
- NEW-20 players download size, NEW-21 bundled mock files, NEW-23 archive key guard, KEY-1 tokens in UserDefaults: low risk, not launch blockers.
- Meta auto-logging before ATT: changing it affects the running install-ad attribution; disclosed in the privacy policy instead.
