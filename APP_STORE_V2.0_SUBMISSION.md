# App Store V2.0 Submission Checklist

Step-by-step for the manual submission of V2.0. Run this whole thing in one sitting on your Mac. Target: submit by **June 4** to leave a 7-day Apple review buffer before June 11 WC kickoff.

Companion files:
- [APP_STORE_V2.0_COPY.md](./APP_STORE_V2.0_COPY.md) — paste-ready listing text
- [APP_STORE_V2.0_SCREENSHOT_PLAN.md](./APP_STORE_V2.0_SCREENSHOT_PLAN.md) — 6 screenshot specs
- `APP_STORE_STRATEGY.md` — full V1 strategy doc for reference

---

## T-minus 3 days (June 1) — final code freeze

- [ ] **All `claude/intelligent-thompson` branch work merged** to your main branch (or whichever branch you ship from). Currently the branch is `claude/intelligent-thompson` and main is `claude/create-markdown-file-hIdbj` — confirm the merge target with `git remote show origin`.
- [ ] **Bump version in xcconfig**:
  - `MARKETING_VERSION = 2.0` in `ios/GoalDigger/Configuration.xcconfig` (the Release config — NOT the gitignored Configuration.xcconfig.example)
  - `CURRENT_PROJECT_VERSION` auto-increments in Xcode at archive time, but verify it lands above the last V1.x build number.
- [ ] **Smoke test on a real device** via TestFlight: install the latest internal build, complete onboarding with WC country selection, verify push delivery for a synthetic content item.
- [ ] **Run the cron auth verification**: `./scripts/verify-cron-auth.sh` should return all 4 ✅. Vault key shape MUST be JWT (`eyJ` prefix). If anything is non-200 in `net._http_response` over the last hour, fix BEFORE submitting (the pipeline must be healthy when the new app's users hit it).

## T-minus 2 days (June 2) — assets ready

- [ ] **Capture 12 screenshots** per [APP_STORE_V2.0_SCREENSHOT_PLAN.md](./APP_STORE_V2.0_SCREENSHOT_PLAN.md) (6 each at 6.9" and 6.3" sizes).
- [ ] **Frame them** in the warm-gradient template with captions above the device.
- [ ] **Optional: record a 15-second app preview video** per the storyboard in the screenshot plan.
- [ ] **Final review of listing copy** in [APP_STORE_V2.0_COPY.md](./APP_STORE_V2.0_COPY.md): description, What's New, promotional text, keywords. Tighten anything that feels off.

## T-minus 1 day (June 3) — archive and upload

This is the longest step (~30-60 min) — schedule it in the morning.

1. **Open Xcode**, open `ios/GoalDigger.xcodeproj`
2. **Select scheme**: GoalDigger
3. **Select destination**: "Any iOS Device (arm64)" — NOT a simulator
4. **Verify Release configuration**:
   - Cmd+, → Locations → confirm Derived Data location
   - Cmd+Shift+, (Edit Scheme) → Archive → Build Configuration = `Release`
5. **Product → Archive** (Cmd+B then `xcodebuild archive` if you prefer CLI)
   - First time can take 5-15 min
   - If signing fails: Window → Devices → Apple Developer → confirm your Apple ID has signing access to the `com.goaldigger.app` App ID
6. **Window → Organizer** opens automatically when archive completes
7. **Click "Distribute App"** → App Store Connect → Upload
8. **Wait for processing** in App Store Connect (5-15 min after upload). You'll get an email when the build is "Ready to Submit."

Common gotchas (search IOS_GOTCHAS.md for the originals):
- xcconfig comment-stripping bug: confirm `SUPABASE_HOST` is bare hostname (NO `https://`) in Release config
- APNs entitlement: `apsEnvironment = production` in `GoalDigger-Release.entitlements`
- No simulator-only code paths leaking into Release (e.g., `#if DEBUG` guards on mock data)
- New Swift files added in V2.0 (Country.swift, CountrySelectionView.swift, etc.) must be in the target's "Compile Sources" build phase. Verified at V1 PR review but check again.

## Submission day (June 4) — App Store Connect

1. **Open App Store Connect** in browser → https://appstoreconnect.apple.com → My Apps → Goal Digger
2. **Click "App Store" tab** → click the `+ Version` button → enter `2.0`
3. **Fill in version metadata** (paste from APP_STORE_V2.0_COPY.md):
   - **What's New in this Version**: paste the "What's New" block (~1100 chars)
   - **Description**: paste the updated full description (~2150 chars)
   - **Keywords**: paste the updated keyword string (~98 chars)
   - **Promotional Text** (170 chars max, editable post-submission): paste the promo
   - **Support URL**: reuse from V1
   - **Marketing URL**: reuse from V1 if you set one
   - **Privacy Policy URL**: reuse from V1 — V2.0 doesn't change data collection

4. **Upload screenshots** (6 per size × 2 sizes = 12 PNGs)
   - Drag-drop into the App Store Connect uploader for each device size section

5. **Optional: upload app preview video** per size

6. **Build section**: select the V2.0 build that was processed (it'll appear in a dropdown once Apple finishes processing)

7. **Version release**: select "Automatically release this version" so V2.0 goes live the moment Apple approves. (If you want manual control over the launch time, select "Manually release" — then you have to click "Release" yourself.)

8. **Click "Save"** at the top right, then **"Add for Review"**, then **"Submit for Review"**

9. **Answer the export compliance questions**:
   - "Does your app use encryption?" → Yes (HTTPS to Supabase counts)
   - "Does your app use only standard encryption?" → Yes (TLS/HTTPS only, no proprietary crypto)
   - "Is your app exempt from export compliance documentation?" → Yes
   - These answers are the same as V1; reuse them.

10. **Answer the "Sign-In Information" questions**:
    - If the app requires a sign-in for review, you can't ship Goal Digger without it being onboarded — provide a demo account OR set "no sign-in required" if onboarding is bypassable
    - The current V2.0 build requires onboarding flow completion, but does NOT require an Apple ID sign-in. Provide the reviewer with: "Open the app and complete the onboarding (any name, pick any country, optionally any PL team). The feed will populate within 10 seconds."

## Post-submission

- [ ] **Track review status** in App Store Connect. Typical review time is 24-48h but can stretch to a week during high-volume periods. Apple peaks (Christmas, WWDC) are slower.
- [ ] **Be ready for rejections**. If rejected:
  - Read the feedback carefully — Apple usually lists the exact guideline number (e.g., 4.2.6 Spam) and a specific reason
  - Common rejection causes for sports apps: copyrighted team logos, official league trademarks. Verify your usage of Premier League / FIFA / country FA logos and crests doesn't fall outside fair use. The data-fetcher pulls from API-Football which licenses crests via their CDN — that's fine for in-app display but watch for screenshot usage that might trigger trademark flags.
  - Fix the issue → bump build number → re-archive → re-upload → resubmit
- [ ] **Once approved + auto-released**, monitor:
  - First 24h of crash logs (Xcode → Window → Organizer → Crashes)
  - First 24h of Supabase function logs (Edge Functions dashboard)
  - First 24h of `client_errors` table for any V2.0-specific exceptions
  - Tweet/post about the launch (the marketing pivot was explicitly to lean into WC — make sure your social presence reflects this)

## Worst-case fallback

If Apple rejects on June 4 and you can't fix + resubmit in time for June 11 launch:

- The existing V1.x build is still live for users — they'll continue to receive PL content
- WC users can't be served until V2.0 is approved, but the backend WC pipeline (gd-news-wc, country pages, etc.) is already running and will buffer content for them
- When V2.0 finally clears, existing PL users see the WC migration sheet on next launch and the buffered country content lands immediately
- Marketing posts can shift to "WC support coming soon — sign up for early access" if review delay forces it

Not ideal, but the worst case isn't catastrophic.

---

## Files referenced

- `ios/GoalDigger/Configuration.xcconfig` — Release config (gitignored — must exist locally with prod values)
- `ios/GoalDigger/GoalDigger-Release.entitlements` — APNs prod entitlement
- `ios/GoalDigger.xcodeproj` — the project to archive
- `IOS_GOTCHAS.md` — the gotchas list (especially #1 xcconfig comment-stripping, #14 JWT shape)
- `RUNBOOK.md` — push pipeline health check SOP if launch-day pushes fail
- `scripts/verify-cron-auth.sh` — pre-submission cron auth check
