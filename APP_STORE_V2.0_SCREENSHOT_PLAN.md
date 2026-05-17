# App Store V2.0 Screenshot Plan

For the V2.0 World Cup update submission. Capture 6 fresh screenshots — 5 reframed from V1 + 1 new (the WC country picker, which is the headline V2.0 feature).

V1 strategy doc had 5 screenshots; this plan keeps the same warm-gradient + caption-above-device frame, just updates the in-app states.

---

## Required device sizes

Per Apple's 2026 App Store requirements:
- **6.9"** (iPhone 16 Pro Max / iPhone 17 Pro Max) — required
- **6.3"** (iPhone 16 / iPhone 17) — required
- **5.5"** (iPhone 8 Plus class) — only required if your build supports iOS < 17; GoalDigger is iOS 17+, so **skip**.
- **iPad Pro 13"** — optional, skip per V1 strategy (iPhone-only focus).

So you need 2 sets of 6 screenshots = 12 PNGs total. Each at the exact pixel dimensions Apple specifies:
- 6.9" → 1320 × 2868 (portrait)
- 6.3" → 1206 × 2622 (portrait)

Use Xcode → Window → Devices and Simulators → click the device → camera button to capture at native resolution. Then frame in a Figma/Photoshop template with the warm-gradient background + caption above.

---

## Pre-capture setup

Before shooting, set up the simulator state so the in-app data is "demo-good":

1. **Fresh simulator install** of the V2.0 build (Cmd+Shift+H from the home screen → Settings → General → Reset → Erase All Content)
2. **Pick a "demo persona"** for consistency across all 6 screenshots:
   - Her name: `Sophie` (warm, mid-20s feel)
   - His name: `Ben` (matches the V1 strategy doc convention)
   - His country: **Argentina** (high-profile WC team, recognisable flag, Messi-era nostalgia)
   - His PL club: **Arsenal** (most recognisable, matches V1 screenshot 2 if reusing the team picker shot)
3. **Pre-populate the feed** with 3-4 hand-picked content_items so the feed screenshot has good copy. Two ways:
   - Easy: log into a TestFlight build that's been running for a few days and has real content
   - Harder: insert hand-picked items into Supabase before capture, filter by `pipeline_source='manual_demo'` so they don't pollute prod feeds
4. **Status bar prep** — set the simulator status bar to a fixed time (`xcrun simctl status_bar <UUID> override --time "9:41" --batteryState charged --batteryLevel 100`). Apple uses 9:41 — match it.

---

## Screenshot sequence (6 total)

### Screenshot 1: "The Hook" (kept from V1)
**Caption:** `Stay in the loop. Win the conversation.`

**What's shown:**
- The welcome/onboarding entry screen
- App name and tagline prominent
- Warm-gradient background (#FAF8F5 → #E8CEB8) behind the device

**Purpose:** Set the tone. Same V1 hook still works — the brand voice hasn't changed.

**Capture state:** Fresh launch → first onboarding screen.

---

### Screenshot 2: "The World Cup" (NEW for V2.0 — the headline feature)
**Caption:** `Pick his World Cup country.`

**What's shown:**
- The new `CountrySelectionView` from the V2.0 onboarding
- Countries grouped by confederation header (UEFA, CONMEBOL, AFC, CAF, CONCACAF, OFC)
- **Argentina** card highlighted/selected
- The continue button visible at the bottom

**Purpose:** Lead with the WC pivot. This is the one screenshot that absolutely must communicate "this app now does World Cup."

**Capture state:** Onboarding → past Welcome/Her/His names → on the Country Selection step → tap Argentina.

**Note:** Argentina has a recognisable flag + Messi association. England works as an alternate if you want UK-market lead. Brazil also works for global lead.

---

### Screenshot 3: "The Club AND The Country" (NEW framing for V2.0)
**Caption:** `Follow both his club AND his country.`

**What's shown:**
- The `OptionalPLTeamView` screen — adding Arsenal alongside Argentina
- Either: the Arsenal card highlighted with a "Selected" state, AND a smaller chip showing Argentina is already picked
- OR: the next-screen "Confirmation" view showing both Argentina + Arsenal in his profile

**Purpose:** Communicate the dual-fandom story. Most WC viewers also watch club football — this app handles both.

**Capture state:** Onboarding → after country selection → on the Optional PL Team step → tap Arsenal.

---

### Screenshot 4: "The Feed" (reframed from V1 screenshot 3)
**Caption:** `Get the updates that matter — all summer.`

**What's shown:**
- The home feed with 3-4 content cards mixed:
  - 1 Arsenal news item (e.g., transfer rumour)
  - 1 Argentina news item (e.g., squad announcement)
  - 1 Argentina matchday/preview card
  - The "caught up" card at the top
- Badges clearly visible: `NEWS`, `MATCH DAY`, with the team chip showing which entity each item is for
- The context switcher chip at the top showing she can flip between Argentina and Arsenal feeds

**Purpose:** Show the dual feed. This is the money shot for V2.0 — proves the app delivers both club AND country content in one place.

**Capture state:** Feed view with the demo persona's items loaded. The feed should be filtered to "Everyone Talking" or "Both" if there's such a toggle, OR just be the default mixed feed.

**CRITICAL:** Use REAL content with the GoalDigger voice. Sample headlines:
- Argentina: `"messi's last dance.\nargentina's squad named tomorrow."`
- Arsenal: `"saka returns.\nfit for the cup semi-final."`
- Argentina: `"argentina vs algeria.\nopener wednesday."`

No lorem ipsum. No generic text. The content IS the product.

---

### Screenshot 5: "The Cheat Sheet" (kept from V1, content updated)
**Caption:** `Know exactly what to say — for every game.`

**What's shown:**
- Detail view on a WC content item (e.g., Argentina vs Algeria match brief)
- Styled talking-point cards
- First talking point readable, in the sister voice:
  - e.g., `"Pre-pour his Mate. Tell him you've seen the lineup — Lautaro starts."`

**Purpose:** Same as V1 — she sees the talking points and thinks "oh, I could actually use this." V2.0 just updates the example to a WC moment.

**Capture state:** Tap a matchday card in the feed → detail view.

---

### Screenshot 6: "The Notification" (kept from V1, content updated)
**Caption:** `Never miss a thing — every match, every result.`

**What's shown:**
- iPhone lock screen with a Goal Digger push notification
- Notification preview:
  - Title: `Argentina ⚽`
  - Subtitle: `Goal Digger`
  - Body: a one-line headline like `"Messi off the bench at 65'. Tell him to come back to the TV."`
- Time visible on lock screen: set to a Saturday afternoon WC kickoff time (e.g., `15:00`) for tournament vibes
- Other typical lock screen elements (battery, signal) for realism

**Purpose:** Shows the push notification experience for the WC use case. Closes the loop visually.

**Capture state:** Trigger a push to the simulator (via push-probe OR a synthetic content_item insert OR a saved `notification_test.apns` file). Capture the lock screen at the moment the notification arrives.

---

## Screenshot design guidelines (same as V1)

- **Device frames:** Use Apple's official device frames (Apple Design Resources) or a clean mockup generator (frame.media, mockuphone, Rotato).
- **Captions:** Above the device, never overlapping the screen content.
  - Font: Plus Jakarta Sans Bold (matches the app's brand typography) OR SF Pro Display Bold as fallback.
  - Color: Dark text (#2D1B2E — the deep mauve from the app palette) on warm background.
  - Size: Large enough to read in App Store thumbnails. ~80-100pt at the source PNG resolution.
- **Background:** Warm gradient (#FAF8F5 → #E8CEB8) or solid `#F5E6D8` from the app palette. NOT white, NOT dark.
- **Consistency:** Same background + caption font across all 6.
- **No annotations:** No arrows, circles, or "Tap here!" labels. The screen should explain itself.

---

## App Preview Video (optional, recommended)

If you have time, a 15-30 second video uploaded alongside the screenshots significantly improves conversion. The V1 strategy doc has a full storyboard in section "App Preview Video." For V2.0:

**Storyboard suggestion (15 sec):**

| Time | Visual | Caption / Voiceover |
|---|---|---|
| 0:00–0:02 | App icon zoom-in | Goal Digger |
| 0:02–0:05 | CountrySelectionView, Argentina selected | "Pick his World Cup country." |
| 0:05–0:08 | Quick feed swipe showing mixed Argentina + Arsenal cards | "Follow his club AND his country." |
| 0:08–0:11 | Detail view on a matchday card with talking points | "Get the conversation hooks." |
| 0:11–0:14 | Lock screen with push arriving | "Never miss a moment." |
| 0:14–0:15 | App icon + tagline | "Stay in the loop. Win the conversation." |

Capture via Xcode → Window → Devices → camera button → record. Or `xcrun simctl io <UUID> recordVideo screenshot.mp4` for a clean simulator recording.

---

## Pre-flight checklist (before exporting the final 12 PNGs)

- [ ] Status bar shows 9:41 (Apple's convention)
- [ ] Battery shown full and charging
- [ ] Notification badges hidden (set Do Not Disturb in simulator settings)
- [ ] Background blurs are off in screens that have them (or use them deliberately for the "wash" effect)
- [ ] No personally identifiable info (real phone numbers, real device names, real Apple ID emails)
- [ ] Brand colors verified against `Theme.swift` (hot rose #E8397D, deep mauve #2D1B2E, warm cream backgrounds)
- [ ] Resolution matches Apple's spec for each device size — Xcode "screenshot" button captures at native resolution
- [ ] Frame is the SAME warm gradient across all 6 screenshots
- [ ] Caption text is identical font + color + size across all 6
