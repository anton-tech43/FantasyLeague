# Goal Digger — iOS / SwiftUI Gotchas

Hard-won lessons from real bugs we shipped and fixed. Read before debugging the same thing twice.

---

## 1. xcconfig + `//` is a comment trap

**Symptom:** Built `Info.plist` shows `SUPABASE_URL = "https:"` even though the source is `https://cwgpsmbunrocrofziqad.supabase.co`. All API calls resolve to `https://rest/v1/...` and fail with `-1003 hostname not found`.

**Cause:** The `//` after `https:` is treated as a comment start by xcconfig and/or the Info.plist build phase. Everything after `//` is silently stripped at build time.

**Fix (canonical, in `Configuration.xcconfig`):** Store the bare hostname; prepend the scheme in Swift.

```xcconfig
SUPABASE_HOST = cwgpsmbunrocrofziqad.supabase.co
```
```swift
let url = URL(string: "https://\(host)/rest/v1")
```

**Don't try:** `https:/$()/host` style escapes — fragile and fails when Info.plist preprocessing runs after xcconfig substitution.

---

## 2. Multiple `.xcodeproj` copies (worktree confusion)

**Symptom:** You edit a Swift file, rebuild in Xcode — the change isn't in the build. The compiled dylib still has the old code.

**Cause:** Two copies of `GoalDigger.xcodeproj` exist (one in main repo, one in a `.claude/worktrees/<name>/` worktree). Xcode is open on the worktree copy; you've been editing the main-repo copy.

**Fix:** Always confirm which `.xcodeproj` Xcode is reading from. Quickest check:
```bash
cat ~/Library/Developer/Xcode/DerivedData/GoalDigger-*/info.plist | \
  /usr/libexec/PlistBuddy -c 'Print :WorkspacePath' /dev/stdin
```
or look at the open project path in Xcode's title bar.

---

## 3. `UIScrollView.appearance().backgroundColor` poisons every text field

**Symptom:** `TextField` background becomes opaque dark when focused/typing. `.background(Color.X)` modifier is ignored. Only happens once you start typing — empty field looks fine.

**Cause:** `UIScrollView.appearance()` is a UIKit appearance proxy that affects **every UIScrollView in the entire app** — including the internal one `UITextField` uses to scroll long text. We had this in `AppDelegate.swift`:
```swift
// THIS POISONS EVERY TEXT FIELD
UIScrollView.appearance().backgroundColor = UIColor(deepMauve)
```

**Fix:** Remove the global appearance proxy. Set scroll-view backgrounds per-view in SwiftUI (`.background(Color.deepMauve)` on the actual ScrollViews that need it). Never set `UIScrollView.appearance()` globally in an app that uses any text input.

**Time wasted before finding this:** several hours of poking at `.textFieldStyle(.plain)`, ZStacks, `RoundedRectangle.fill`, even a UIViewRepresentable wrapper. None of it worked because the fix had to be at the `UIScrollView.appearance()` level.

---

## 4. SwiftUI `.environment(\.colorScheme, .light)` doesn't reach UIKit

**Symptom:** App forces dark mode (`UIUserInterfaceStyle = Dark` in Info.plist + `.preferredColorScheme(.dark)` on root). Adding `.environment(\.colorScheme, .light)` to a TextField subtree changes nothing — UIKit-rendered controls still show dark visuals.

**Cause:** SwiftUI environment values only flow through SwiftUI views. UIKit views (which TextField uses internally) read `UITraitCollection`, which is set at the window/UIViewController level — not by SwiftUI environment.

**Fix:** Use `overrideUserInterfaceStyle = .light` on the actual UIKit view (e.g. via UIViewRepresentable). Or accept system defaults and don't try to mix forced dark + light overrides.

---

## 5. SwiftUI `TextField` + `@FocusState` background overrides

**Symptom:** Even without `UIScrollView.appearance()` issues, focused TextField sometimes paints a system background that defeats `.background(Color.X)`.

**Cause:** SwiftUI internal: focus state can render system styling that sits *above* the `.background()` modifier in the layer order.

**Fix (proven):** Use `.background(SomeShape().fill(Color.X))` with an explicit Shape — survives focus better than `.background(Color.X)`. Or anchor a `RoundedRectangle.fill(...)` *behind* the TextField inside a ZStack. Or fall back to `UIViewRepresentable` wrapping `UITextField` if both fail.

---

## 6. `cardHeight = geo.size.height` vs `UIScreen.main.bounds.height`

**Symptom:** Either (a) you see a slice of the next card peeking under the current one, or (b) the bottom of the current card disappears behind the tab bar.

**Cause:**
- `geo.size.height` = visible viewport (excludes tab bar safe area)
- `UIScreen.main.bounds.height` = full device screen (includes everything)

**Fix:** Pick based on intent:
- "Each card fills the visible viewport, accept brief next-card-peek during scroll transitions" → `geo.size.height`
- "Each card extends behind tab bar, next card hidden at full screen height" → `UIScreen.main.bounds.height` AND adjust zone ratios so content stays in the visible portion (don't put the talking-point in the bottom 15% behind the tab bar)

---

## 7. SwiftData cache masks API failures

**Symptom:** App appears to load fresh content even when API calls are silently failing. Hours debugging "is the API broken?" and finding it's actually working — just the iOS app is showing yesterday's cached data.

**Cause:** `FeedView.loadInitial()` shows SwiftData-cached items immediately (good UX), then re-fetches in the background. If re-fetch fails silently, the UI keeps showing cache — no error visible to user.

**Fix:** Two things:
1. Always check what the actual API response is (curl the endpoint with the iOS-shape `select=...` query string)
2. Add explicit error states in `FeedView` so silent fetch failures surface, not just cache fallback

---

## 8. `displayContext` was gated on the wrong flag

**Symptom:** Analogies generated and AI-critic-approved (`analogy_critic_score.verdict = "approve"` in DB), but iOS shows the factual fallback line instead.

**Cause:** `displayContext` checked `analogyApproved` — the **human review flag**, always `false` for auto-pipeline content. So even AI-approved analogies got hidden behind fallbacks.

**Fix:** Trust the AI critic. Show `immersive_context` if non-null (the pipeline already nulls rejected ones at the DB level). Flag `analogyApproved` is for a future human-in-the-loop workflow that doesn't exist yet.

---

## 9. AI critic was rejecting and silently nulling analogies

**Symptom:** Most cards showed factual fallback, not the witty analogy that's the actual product.

**Cause:** Critic flow was: score → if reject, null out `immersive_context` → fallback shown. No second chance.

**Fix:** `runAnalogyAICritic` now does score → if reject, **rewrite using critic's specific feedback** → re-score → save the rewrite if it now passes, else fall back. Most analogies now survive into production. The `analogy_rejections` table logs both the original failure and the saving rewrite for audit.

---

## 10. Detail view going blank on tap

**Symptom:** Tap a feed card → detail screen is blank except for the back button.

**Cause:** `ContentDetailView.loadItem()` fetched by ID. If `fetchItem(id:)` returned empty (stale UUID, transient network blip, etc.), `item` stayed `nil`, `isLoading` flipped false, and the body rendered nothing — no `else` branch.

**Fix:** Two things:
1. Pass the full `ContentItem` through navigation as `preloadedItem` — feed already has it, no re-fetch needed
2. Add explicit error state ("Couldn't load this story" + retry button) so silent failures never blank-screen

---

## 11. New Swift files need a fresh build before Xcode indexes them

**Symptom:** Created `OnboardingTextField.swift`, build fails with `Cannot find 'OnboardingTextField' in scope`.

**Cause:** Xcode auto-syncs file-system additions to `.xcodeproj` but the project hasn't been re-indexed yet. The next build picks them up.

**Fix:** `Cmd+Shift+K` (Clean Build Folder) then `Cmd+R`. Or just hit Run a second time.

---

## 12. `Configuration.xcconfig` is gitignored

**Symptom:** Cloned repo on a new machine, app silently runs in mock mode.

**Cause:** `Configuration.xcconfig` holds Supabase credentials and is intentionally gitignored. New checkouts have no real config.

**Fix:** Copy `Configuration.xcconfig.example` to `Configuration.xcconfig` and fill in real values (or grab them from another machine / 1Password).

---

## 13. Two plan files in `~/.claude/plans/` cause confusion

**Symptom:** Plan UI shows stale plan content even after I overwrite it.

**Cause:** Multiple plan files exist in `~/.claude/plans/` from different sessions. The "active" file is the one referenced in the most recent system reminder. Other files linger with stale content.

**Fix:** When in doubt, look at `ls -la ~/.claude/plans/` and check mod times. Mark stale files as superseded explicitly.

---

## 14. Cron auth fails silently, and the cron key is a random secret, never a JWT

**Rule reversed on 2026-10-05.** Until then this section said the Vault key had to be the legacy `service_role` JWT. It is now a random 80-character secret, and `./scripts/verify-cron-auth.sh` fails if Vault holds a JWT. Never put a JWT back.

**Symptom:** Push pipeline silently dies. pg_cron reports `status=succeeded` for every tick. But `net._http_response` shows 401 on every cron call. Functions never run. Lasts for days because `cron.job_run_details` is the wrong place to watch.

**How it works now:** pg_cron sends `get_cron_service_key()` (Vault `cron_service_key`) as the Bearer. Every cron target deploys `--no-verify-jwt`, so the gateway never parses the header; `_shared/require-service-auth.ts` compares it as a string, in constant time, against the Edge secret `CRON_AUTH_KEY`. The two stores must hold the same value, and `backend/.env`'s `SUPABASE_SERVICE_ROLE_KEY` holds it too for manual ops `curl`.

It goes wrong in two ways:
1. **Vault and `CRON_AUTH_KEY` disagree** (one was updated without the other): every cron tick 401s.
2. **A function deployed without `--no-verify-jwt`**: the gateway rejects a non-JWT Bearer before the function runs.

**Diagnosis:** Always cross-check TWO tables, not just one:
```sql
-- Cron-level success (SQL ran):
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 5;
-- HTTP-level success (function was reached):
SELECT id, status_code, LEFT(content::text, 100) FROM net._http_response ORDER BY id DESC LIMIT 5;
```
If `cron.job_run_details.status='succeeded'` but `net._http_response.status_code != 200`, the cron's auth header is broken.

**Check:** `./scripts/verify-cron-auth.sh` (Vault entry present, accessor present, key is a random secret of 80 characters and not `eyJ...`, last 15 minutes of HTTP responses all 200).

**Fix:** `./scripts/rotate-cron-key.sh`. It generates a new key, sets `CRON_AUTH_KEY` and Vault back to back, updates `backend/.env`, and compares the digests of all three. Never write a key into one store by hand.

**Sources:** Phase 27.3 (push pipeline dead May 11 → May 17) and Lessons 56/57 in IMPLEMENTATION_PROGRESS.md for the original silent failure; the 2026-10-04 QA pass for the rotation (applied 2026-10-05).

---

## 15. Anti-spam's "gap check" compared each item against itself

**Symptom:** User reports "didn't get a push for the West Ham sunday brief" / "didn't get a push for Liverpool" / "didn't get a push for X". Multiple incidents, no obvious pattern. `cron.job_run_details` clean. `net._http_response` clean. `pipeline_health` has a row saying "All tiers blocked by anti-spam rules" but no reason field.

**Cause:** The legacy `_shared/anti-spam.ts` `gap_too_short` check did this:

```typescript
// Find this team's most recent published_at:
const { data } = await supabase
  .from("content_items")
  .select("published_at")
  .eq("team_id", teamId)
  .eq("status", "published")
  .order("published_at", { ascending: false })
  .limit(1);

if (data?.[0]?.published_at) {
  const hoursSinceLast = (Date.now() - new Date(data[0].published_at).getTime()) / (1000 * 60 * 60);
  if (hoursSinceLast < 3) return { canSend: false, reason: "gap_too_short" };
}
```

But the **routine post script inserts the new content_item with `status='published'` BEFORE notification-sender's anti-spam check runs**. The "most recent published_at" query returns the row that just got inserted. `hoursSinceLast` is always ~0. The check always blocks.

The bug only fires for teams that didn't have a recent PRIOR push in the last 24h (which is what "I never get pushes" looks like to the user).

The aggregated log line `"All tiers blocked by anti-spam rules"` made it look like a deliberate rate-limit decision. The individual reason (`gap_too_short` per tier) was buried in `console.log` and never persisted to `pipeline_health`.

**Diagnosis:** When a push doesn't arrive, look at `pipeline_health` for the team_id around the publication time. If you see `stage='publish'` + `status='skipped'` + `message='All tiers blocked by anti-spam rules'`, you've hit this class.

**Fix (committed in `5c9cbf2`, deployed 2026-05-17):** Removed anti-spam entirely. Tier segmentation in `notification-sender` (`minTierForType`) is sufficient volume control. Quiet hours moved to iOS Do Not Disturb on the device.

**Rule for future "compare item against most recent" checks:** When a check needs to compare a new row against "most recent X," it MUST do ONE of:
- Query BEFORE the insert (re-order the code)
- Exclude the candidate row's id: `.neq("id", currentId)`
- Query a different table or a more specific filter (e.g., `pushed_at IS NOT NULL` not just `status='published'` — "last PUSHED" excludes the just-inserted "published but not pushed").

Never trust "ORDER BY ts DESC LIMIT 1" to find anything other than the row you just touched, unless the filter explicitly excludes that row.

**Sources:** May 17 audit during live Everton match. Phase N self-reference bug hunt in the same session found zero OTHER instances of this pattern in the codebase.

---

## 16. Three live pipelines, and only one of them is the live brief

**Symptom:** During a live match a push "goes missing" and you search `content_items` or `live_match_briefs` for it, find nothing, and conclude the routine failed.

**Cause:** Match-time output travels three separate routes:

- **Live pushes (kickoff, goal, half-time, full time):** sent directly by `match-watcher` (`sendPlayingTeamPush`). Nothing is written to `content_items`. Who gets which is decided by `_shared/push-tiers.ts`: a goal reaches every tier, kickoff and half-time need tier 2, early domestic cup rounds get no kickoff or half-time push, and semi-finals and finals go to everyone. Half-time and full-time pushes end with a line to say.
- **Live briefs:** `gd-live-brief` → `live_match_briefs` → iOS polls `live-brief-current` every 60 s → the live box at the top of the club feed (tier 2+). **No push by design.**
- **Matchday and post-match articles:** `gd-matchday` → `content_items`, **feed-only**. `post_news.sh` (routines repo) sets `push_eligible=false` on every Premier League matchday article because match-watcher already sent the full-time push; the article is what she opens from it. `notification-sender` only selects `push_eligible=true`.

The Live Activity on the lock screen is a fourth surface, updated by `match-watcher` through the Live Activity tokens.

**Diagnosis:** For a missing live push, read `pipeline_health` rows with `stage = 'apns_send'` around the minute it should have fired, and check the device's `tier` against `push-tiers.ts`. For a missing live brief, read `live_match_briefs` for the fixture. For a missing article, read `content_items`.

**Sources:** May 17 confusion during Everton-Sunderland (when the only in-match push was FT); live pushes for clubs since 2026-09-06 (migration 083); tier gating since 2026-09-08.

## 17. Testing Dynamic Type in the simulator can crash SpringBoard

`xcrun simctl spawn <udid> defaults write -g UIPreferredContentSizeCategoryName <value>` is
the only way to force a text size without tapping. The value MUST be one of the exact UIKit
constants (`UICTContentSizeCategoryXS`, `S`, `M`, `L`, `XL`, `XXL`, `XXXL`,
`UICTContentSizeCategoryAccessibilityM`, `AccessibilityL`, `AccessibilityXL`, `AccessibilityXXL`,
`AccessibilityXXXL`). Anything else (`AccessibilityXXXL` without the prefix, a typo) makes
SpringBoard assert in `UIContentSizeCategoryCompareToCategory` every time the lock screen is
drawn: "SpringBoard quit unexpectedly" ten times in a morning (2026-09-09, a review agent's
simulator). Always `defaults delete -g UIPreferredContentSizeCategoryName` when done, and do
it on a throwaway simulator, never on the one Anton uses.


---

## 18. The Meta SDK: `FacebookCore` (SPM) vs `FBSDKCoreKit` (the module), and ATT timing

Added 2026-09-16 for app-install ads: Meta locks a campaign to iOS ≤ 14.4 unless the app
carries the SDK **and** `SKAdNetworkItems`. Five things that bite:

1. **Add the package with the script, never by hand.** `ios/scripts/add_facebook_sdk.rb`
   (xcodeproj gem, idempotent) owns the `XCRemoteSwiftPackageReference`, the
   `XCSwiftPackageProductDependency` and the Frameworks-phase link, plus the version bump.
   Hand-editing `project.pbxproj` for SPM is how you get a project that opens but doesn't link.
   Re-run it, then `xcodebuild -resolvePackageDependencies`, and commit `Package.resolved`.
2. **The SPM product is `FacebookCore`; the module you import is `FBSDKCoreKit`.** They don't
   match, and `import FacebookCore` doesn't compile. `FacebookAEM` is bundled inside
   `FacebookCore` — don't add it separately, and don't add `FacebookLogin` (we have no login).
   The product goes on the **app target only** — never on `GoalDiggerLiveActivity`.
3. **Never call `AppEvents.shared.activateApp()`.** `Settings.shared.isAutoLogAppEventsEnabled`
   (we set it explicitly) makes the SDK log `fb_mobile_activate_app` itself on
   `applicationDidBecomeActive`. Calling it too *double-logs* every install/session and
   corrupts the ad metrics you added the SDK for.
4. **ATT only while the app is `.active`.** `ATTrackingManager.requestTrackingAuthorization`
   is silently denied if the app isn't frontmost. `Attribution.requestTrackingIfNeeded()`
   waits 1.5 s after `MainTabView` appears, asks once per install (`attPrompted`), and never
   runs during onboarding — the notification prompt is already there, and two system sheets
   back to back get both declined. `syncTrackingStatus()` re-tells the SDK the standing answer
   on every launch; the SDK does not remember it across relaunches.
   `-gdSkipATT`/`-gdPresetTeam` skip the prompt (the screenshot harness must stay
   deterministic), `-gdForceATT` bypasses every gate to prove the sheet still appears.
5. **The client token in `Info.plist` is public, the app secret is not.** `FacebookClientToken`
   is designed to ship in the binary (it's in every Meta app's plist), so it lives in the repo
   rather than in the gitignored `Configuration.xcconfig` — one less thing a fresh checkout
   has to fill in. The **app secret must never** reach the app, an xcconfig, or this repo.

v18 exposes no public `isSDKInitialized`; the only public proof the launch path ran is the
`Bool` returned by `ApplicationDelegate.shared.application(_:didFinishLaunchingWithOptions:)`
(`false` when it has already run). That's what `Attribution.sdkLaunched` stores, and what
`Attribution.selfCheck()` asserts alongside the Info.plist keys — launch with
`-gdCheckFBSDK` and grep the device log for `[FBSDK]`.

---

## 19. Installing the app from DerivedData: the glob picks the wrong build

`~/Library/Developer/Xcode/DerivedData` accumulates one `GoalDigger-<hash>` directory per
checkout, per worktree and per Xcode reindex — there were several on 2026-09-22, and the
newest by name is not the newest by date. A `GoalDigger-*/Build/Products/Debug-iphonesimulator/GoalDigger.app`
glob installed a **July binary with three tabs** onto the simulator, which then "proved" that
the day's work had not shipped. Ask the build system where it put the thing instead:

```sh
APP="$(xcodebuild -project ios/GoalDigger.xcodeproj -scheme GoalDigger \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -showBuildSettings \
        | awk -F' = ' '/ TARGET_BUILD_DIR/ {print $2}')/GoalDigger.app"
xcrun simctl install <udid> "$APP"
```

Same rule for any other artefact: `TARGET_BUILD_DIR`, `BUILT_PRODUCTS_DIR` and
`CODESIGNING_FOLDER_PATH` come out of `-showBuildSettings` with the same flags as the build.

**And every harness launch needs `-gdSkipATT`.** `Attribution.requestTrackingIfNeeded()` fires
1.5 s after `MainTabView` appears (gotcha 18.4), so a screenshot taken any later than that is a
screenshot of the ATT sheet:

```sh
xcrun simctl launch <udid> com.goaldigger.app -gdSkipATT -gdTab 2 -gdMyTurnModule lingo
```
