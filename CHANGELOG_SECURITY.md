# Goal Digger — Security & Architecture Changelog

**Purpose:** This document tracks all security fixes, GDPR changes, and architectural decisions made during the security audit of April 2026. **Every agent must read this before starting work.**

**Date:** April 6, 2026
**Audit performed by:** Cybersecurity & Best Practices review agent

---

## Summary of Changes

| # | Change | Severity Fixed | Files Modified |
|---|--------|---------------|----------------|
| 1 | Credentials moved from hardcoded Swift to xcconfig build-time injection | CRITICAL | BUILD_PLAN.md, AGENT_CONTRACTS.md |
| 2 | device_tokens table hardened with CHECK constraint, rate limit trigger, restricted RLS | HIGH | BUILD_PLAN.md |
| 3 | RSS/API input sanitization and prompt injection defenses added | HIGH | PROMPTS.md, BUILD_PLAN.md |
| 4 | GDPR-compliant privacy policy, "Delete My Data" feature, accurate App Store claims | HIGH | BUILD_PLAN.md, PRD.md, APP_STORE_STRATEGY.md |
| 5 | Content Safety review bot (Bot 4) added to pipeline | MEDIUM | PROMPTS.md, AGENT_CONTRACTS.md |
| 6 | Review bot JSON parsing security note added | MEDIUM | AGENT_CONTRACTS.md |
| 7 | Separate dev API key required for Pipeline Agent | LOW | AGENT_CONTRACTS.md |

---

## Detailed Changes

### 1. CRITICAL: Credentials Moved to Build-Time Configuration

**What changed:**
- `APIClient.swift` in BUILD_PLAN.md no longer contains hardcoded `SUPABASE_URL` or `SUPABASE_ANON_KEY`
- Credentials are now loaded from `Info.plist`, which reads from `Configuration.xcconfig`
- `Configuration.xcconfig` is in `.gitignore` — never committed
- `Configuration.xcconfig.example` is committed as a template

**iOS Agent must:**
- Create `Configuration.xcconfig` from the `.example` template
- Set the Xcode project to use this xcconfig for both Debug and Release
- Read credentials via `Bundle.main.infoDictionary` — see updated `APIClient.swift` code in BUILD_PLAN.md Step 2.3

**Backend Agent must:**
- Write real credential values to `ios/GoalDigger/Configuration.xcconfig` (gitignored) during handoff
- Commit `Configuration.xcconfig.example` with placeholder values
- Never pass secrets via commit messages or shared documents

### 2. HIGH: device_tokens Table Hardened

**What changed in BUILD_PLAN.md schema:**
- `apns_token` column now has a `CHECK` constraint: must be 64-character hex string (`'^[a-fA-F0-9]{64}$'`)
- A `BEFORE INSERT` trigger enforces a global rate limit (max 500 new registrations per hour)
- RLS UPDATE policy now restricts anon role to only changing `team_id` and `updated_at` — cannot modify `apns_token` or `is_active`

**Backend Agent must:**
- Include these constraints in `001_initial_schema.sql`
- Implement the column-level RLS policy as documented
- Test that invalid tokens (non-hex, wrong length) are rejected at the database level

### 3. HIGH: Input Sanitization for LLM Pipeline

**What changed in PROMPTS.md:**
- New section "SECURITY: Input Sanitization & Prompt Injection Defense" with 6 mandatory sanitization rules
- Content generator system prompt now includes security clause (rule 8) and content safety clause (rule 9)
- User message template wraps external data in `<external_data>` XML tags with trust_level attribute
- Reminder at end of template reinforces that external data is untrusted

**What changed in BUILD_PLAN.md:**
- New shared utility `input-sanitizer.ts` added to project structure

**Backend Agent must:**
- Implement `_shared/input-sanitizer.ts` following the 6 rules in PROMPTS.md
- Call sanitizer in `data-fetcher/index.ts` BEFORE storing to `raw_fetch_logs`
- Call sanitizer again in `content-generator/index.ts` before building the prompt

**Pipeline Agent must:**
- Include the security and content safety clauses in ALL prompts (news and matchday generators)

### 4. HIGH: GDPR Compliance

**What changed:**
- BUILD_PLAN.md Step 5.3 now contains a full GDPR-compliant privacy policy template
- New "Delete My Data" feature requirement added (Step 5.3, item 7)
- New Edge Function `delete-my-data/` added to project structure
- PRD.md has new Section 9.1 "Privacy & Data Handling"
- APP_STORE_STRATEGY.md privacy claim updated from "no data collection" to accurate description

**Backend Agent must:**
- Implement `delete-my-data/index.ts` Edge Function that accepts an APNs token and deletes the corresponding row
- Host the privacy policy at a public URL before App Store submission
- Execute a DPA with Supabase (manual step for the founder)

**iOS Agent must:**
- Add "Delete My Data" button to Settings screen
- Implement the deletion flow: call Edge Function → clear local data → return to Welcome screen
- Add a link to the privacy policy in Settings

### 5. MEDIUM: Content Safety Review Bot Added

**What changed in PROMPTS.md:**
- New "Review Bot 4 — Content Safety" (Section 6) screens for: personal life comments, defamation, discrimination, inappropriate content, copyright violations
- Table of Contents renumbered
- Pipeline order is now: Tone → Accuracy → Brevity → Safety

**What changed in AGENT_CONTRACTS.md:**
- Contract 6 updated to reference 4 review bots (not 3)
- JSON parsing security note added: failed parses must be treated as FAIL, not PASS

**Backend Agent must:**
- Add the 4th review bot call in `content-reviewer/index.ts`
- Update `pipeline_health` stage values to include `'safety_review'`
- Wrap all `JSON.parse` calls in try/catch — parse failure = review FAIL

### 6. MEDIUM: Review Bot JSON Parsing Security

**What changed in AGENT_CONTRACTS.md:**
- Explicit security note: `JSON.parse` of review bot responses must be wrapped in try/catch with schema validation
- Parse failures are treated as FAIL (not pass) — defense against adversarial content manipulating review output

### 7. LOW: Separate Dev API Key for Pipeline Agent

**What changed in AGENT_CONTRACTS.md:**
- Pipeline Agent's `ANTHROPIC_API_KEY` must be a separate key from production
- Named `goaldigger-dev` in Anthropic Console with lower rate limits

---

## Outstanding Items (Not Yet Fixed)

| Item | Severity | Status | Notes |
|------|----------|--------|-------|
| Automated testing strategy | HIGH | Deferred to post-build | User will be walked through XCTest (iOS), Deno test (Edge Functions), and prompt regression tests after the app is built. Do NOT block on this during build phase. |
| CI/CD pipeline | MEDIUM | Not started | Recommended: GitHub Actions for Edge Function deploy + iOS build |
| Certificate pinning on iOS | MEDIUM | Not started | ATS provides baseline protection |
| APNs key rotation plan | MEDIUM | Not started | Document annual rotation schedule |
| RSS source terms of service review | MEDIUM | Not started | Legal review needed before launch |
| Crash analytics (Sentry/Crashlytics) | LOW | Not started | Apple's built-in crash reports are minimum viable |

---

*This changelog is authoritative. If you see a conflict between this document and older content in BUILD_PLAN.md or AGENT_CONTRACTS.md, this document reflects the latest decisions.*
