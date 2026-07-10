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

## 14. Supabase has TWO service-role key formats. Edge Function invocation needs JWT shape

**Symptom:** Push pipeline silently dies. pg_cron reports `status=succeeded` for every tick. But `net._http_response` shows 401 "UNAUTHORIZED_INVALID_JWT_FORMAT" on every cron call. Functions never run. Lasts for days because `cron.job_run_details` is the wrong place to watch.

**Cause:** Supabase issues two service-role tokens that both work for PostgREST data writes:
- **Legacy `service_role` JWT** — `eyJhbGc...` 219 chars, three base64 segments separated by dots.
- **New `sb_secret_*`** — `sb_secret_GXBb...` 41 chars, opaque prefix-based.

The Supabase Edge Function **gateway** runs a `verify_jwt` check on the Authorization header BEFORE invoking the function code. It requires JWT shape — three-segments-with-dots. The new `sb_secret_*` format fails the gateway check and returns 401 before any function code runs.

Function-INTERNAL PostgREST calls (the function's `SUPABASE_SERVICE_ROLE_KEY` env reading the new format) work fine — PostgREST accepts both.

This bites in three places:
1. **Vault entries used by pg_cron** to build a `Bearer ...` header. MUST be JWT shape, or every cron tick 401s.
2. **External `curl` scripts** invoking Edge Functions. Same constraint.
3. **Anywhere a Bearer is sent to `/functions/v1/*`.**

**Diagnosis:** Always cross-check TWO tables, not just one:
```sql
-- Cron-level success (SQL ran):
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 5;
-- HTTP-level success (function was reached):
SELECT id, status_code, LEFT(content::text, 100) FROM net._http_response ORDER BY id DESC LIMIT 5;
```
If `cron.job_run_details.status='succeeded'` but `net._http_response.status_code != 200`, the cron's auth header is broken.

**Quick check on Vault key shape:**
```sql
SELECT LEFT(get_cron_service_key(), 3) AS prefix, LENGTH(get_cron_service_key()) AS len;
-- prefix=eyJ + len ~219 → JWT format ✓
-- prefix=sb_ + len ~41 → wrong format, will 401 ✗
```

**Fix:** put the legacy `service_role` JWT into the Vault entry that crons read. It's still valid for Edge Function invocation even after rotation (rotation only disables it for direct PostgREST writes).
```sql
SELECT vault.update_secret(
  (SELECT id FROM vault.secrets WHERE name='cron_service_key'),
  '<legacy JWT from backend/.env SUPABASE_SERVICE_ROLE_KEY>',
  'cron_service_key',
  'JWT-format bearer for Edge Function gateway. MUST start with eyJ.'
);
```

**Sources:** Phase 27.3 (push pipeline dead May 11 → May 17), Lessons 56/57 in IMPLEMENTATION_PROGRESS.md.

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

## 16. `live_match_briefs` are browse-only — they DO NOT push

**Symptom:** During a live match, user expects an HT or 75' push notification. Match-watcher fires gd-live-brief on the trigger. `content_items` has no new row for the user's team. Look in `client_errors` — nothing. Look in `pipeline_health` — nothing relevant. Conclude "silent failure." Then re-conclude "the routine session must have errored." Then waste 30 min diagnosing.

**Cause:** Live briefs and matchday briefs are **two separate pipelines with separate destination tables and separate UX surfaces**:

- `gd-matchday` routine → INSERT INTO `content_items` (type='matchday') → `notification-sender` reads → APNs push to user's device. **Pushes.**
- `gd-live-brief` routine → INSERT INTO `live_match_briefs` (NOT content_items) → iOS `FeedView` polls `live-brief-current` Edge Function every 60s → renders as `LiveMatchCard` at the top of the feed. **No push by design.**

The rationale: live HT/75' briefs are reactive content for users who are already watching the match (they opened the app). Pushing on top of that would over-notify users who don't need the prompt.

**Rule:** If you ever wonder "why didn't the HT push arrive?" the answer is: it wasn't supposed to. The only in-match push is at FT, via `gd-matchday` → `content_items` → notification-sender.

**Diagnosis:** When investigating "missing push during a live match":
1. First check `live_match_briefs` for the match — if a row exists with the right `trigger_label`, the live brief pipeline worked correctly. The user sees it as a LiveMatchCard.
2. The only push to expect during a match is FT — and that's a SEPARATE pipeline (gd-matchday).

**Future tickets:** If we want goal-time pushes (currently flagged as v1.1.1 in `LIVE_BRIEF_PROMPT.md`), they need a new pipeline: either a new content_item type or a separate goal-trigger Edge Function that writes to content_items. The `live_match_briefs` table won't reach the push path.

**Sources:** May 17 confusion during Everton-Sunderland match, captured in real time.
