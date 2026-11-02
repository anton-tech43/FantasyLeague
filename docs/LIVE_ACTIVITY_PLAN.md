# Live Activity updates: why so many never arrive, and the plan

Written 2026-11-02. Nothing in the backend has changed. One app-side fix is
committed (`4ced911`) and goes out in the next build.

## 1. What we measured

| Fixture | Push-to-start sent | `update` tokens registered |
|---|---|---|
| Liverpool v Arsenal 1557453, 2026-11-01 | 110 sent, 4 failed (`la:1557453:start:p10`) | 37: **25 within 5 s** of the start, then 12 spread across the match (16:40, 16:45, 16:46 … 18:55) |
| Newcastle v Everton 1557455, 2026-11-02 | 7 sent, 0 failed | **0** |
| Four matches on 2026-10-31 | not logged (`la_send` began 11-01) | 1, 1, 2, 4 |

Queries:

```sql
select kind, fixture_id, is_active, count(*), max(updated_at)
  from live_activity_tokens where updated_at > now()-interval '5 days' group by 1,2,3;
select created_at, target, message from pipeline_health
 where stage='la_send' and created_at > now()-interval '5 days' order by 1;
```

**The Newcastle sample is mostly dead installs.** Of the 7 push-to-start
tokens: 3 are `development` (Xcode builds from 2026-10-29), and 3 of the 4
`production` ones last checked in on 09-27, 10-05 and 10-18. All 2.x builds
upsert the token on every return to the app, so `updated_at` is roughly the
last time she opened it. Realistically one live phone was in that sample.

**Liverpool v Arsenal is the real number.** About 60 to 85 live production
installs, 37 tokens: 25 at once, the rest later. Across all clubs 36 of 170
active push-to-start rows are `development`. Count them out of any rate.

Every phone without a token keeps a frozen card. match-watcher only updates
through `kind='update'` rows, and so does `la-end-sweep`. So the card shows
0-0 through every goal, reads "No recent update" after 20 minutes
(`LA_STALE_SECONDS`), and stays until she opens the app (the foreground
cleanup ends it) or the system's 8-hour limit runs out.

## 2. Root cause

The app code is not the main cause. 2.2 (12), 2.3 (16) and this branch all
start watching for tokens in `AppDelegate.didFinishLaunching`, so a
background launch is covered. The 25 tokens that arrived within seconds came
from 2.2/2.3 phones. `register_la_token` accepts the same follow-set the
push-to-start rows already passed, and `check_la_token_rate_limit` only warns
at 50 an hour and rejects at 2,000. The start payload carries
`attributes-type`, `attributes` with `fixtureId`, `content-state`, `alert`,
`timestamp` and `stale-date`, which is everything Apple's documented token
payload needs.

What blocks the token is on the iOS side:

1. **She has not tapped Allow.** A push-started Live Activity shows an
   inline Allow / Don't Allow under the card. Apple DTS confirmed this on the
   forums: until she makes an explicit choice, the app is not registered for
   updates, and the prompt comes back on every later push-started activity
   ("it resolves after the 3rd or 4th time"). Developers report that
   `pushTokenUpdates` fires only after Allow, and that a Live Activity the
   app starts itself gets its token at once
   ([825419](https://developer.apple.com/forums/thread/825419),
   [800669](https://developer.apple.com/forums/thread/800669)). This is the
   best fit for the 12 late tokens: each is someone tapping Allow during the
   match. iOS wakes the app and the token arrives.
2. **The app was force-quit.** Apple says that on a push start the system
   "starts a new Live Activity, wakes up your app, and grants it background
   runtime", and that is when the update token arrives
   ([Apple docs](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)).
   Several developers report that after a swipe-away in the app switcher the
   card still appears but `pushTokenUpdates` never fires. The thread is
   unanswered by Apple
   ([834923](https://developer.apple.com/forums/thread/834923),
   [826170](https://developer.apple.com/forums/thread/826170)).
3. **Dead or dormant installs and dev tokens** (above). These inflate the
   number of starts sent, not the number of failures.
4. **Two app gaps** (fixed in `4ced911`):
   - `pushTokenUpdates` hands each token over once, and the POST was `try?`.
     A failed request lost that card for the whole match. So did a token that
     arrived before `AppState` was readable, for example a launch before the
     first unlock after a reboot.
   - The foreground fallback deliberately never touched a running activity.
     For a push-started card with no token, that left her frozen card frozen
     even with the app open in front of her.

No Apple document or forum thread gives a count. Rank 1 versus rank 2 is our
inference from the timing pattern.

## 3. What Apple documents (and what changed by iOS version)

Source: [Starting and updating Live Activities with ActivityKit push notifications](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications).
Also [WWDC23 10185](https://developer.apple.com/videos/play/wwdc2023/10185/),
[WWDC24 10069 Broadcast updates](https://developer.apple.com/videos/play/wwdc2024/10069/) and
[WWDC25 278 What's new in widgets](https://developer.apple.com/videos/play/wwdc2025/278/).

| Topic | What it says |
|---|---|
| Push-to-start | iOS 17.2+. `pushToStartTokenUpdates`; the app need not have started an activity. Start payload: `event: start`, an `alert` (required), `attributes-type`, `attributes`. |
| Update token of a push-started activity | Arrives while the system "wakes up your app". Before iOS 18 you use it like a token from an in-app start. **iOS 18+: "you can add `input-push-token: 1` to your payload to start a Live Activity and receive a new push token."** Our start payload does not send it. Forum reports say it changes little, but it is the documented iOS 18 form. |
| Channels (broadcast) | iOS 18+. Turn on Broadcast Capability for the App ID in the developer portal (Xcode cannot). Create a channel per event (`POST /1/apps/<bundle>/channels`; up to 10,000 per environment; delete when done). Start with `input-push-channel: <id>` in the push-to-start payload. Then **one** `POST /4/broadcasts/apps/<bundle>` with `apns-channel-id` updates every subscriber, with **no per-activity token and no app wake**. "If you send this payload to a device that doesn't run iOS 18 or later … the Live Activity doesn't start." A broadcast cannot start an activity. For sports, use storage policy 0 ("No Message Stored", higher publishing budget, `apns-expiration: 0`). |
| Headers | `apns-push-type: liveactivity`, `apns-topic: <bundle>.push-type.liveactivity`, priority 5 or 10. We do this. |
| Budget | Priority 10 counts toward an hourly budget; priority 5 does not. `NSSupportsLiveActivitiesFrequentUpdates` raises it, and she can switch it off in Settings (`ActivityAuthorizationInfo.frequentPushesEnabled`). We have the key, send minute-only updates at 5 and goals/status at 10. |
| `timestamp` | Must increase; stale ones are ignored. We send `now`. |
| `stale-date` | Advances with each update; the state becomes `.stale`. Ours: start/update now+20 min, half time now+30 min. |
| `dismissal-date` | Default up to 4 h after end; past = immediately. Ours: 30 min. |
| `relevance-score` | Orders two simultaneous activities (her two clubs). We do not send it; low priority. |
| Lifetime | Active up to 8 h, then it ends. |
| iOS 26 | `Activity.request(…, alertConfiguration:, start: Date)` **schedules** an activity from the foreground for a future date ("for an upcoming sports game"). The system starts it even with the app in the background. |
| Allow prompt | Not in Apple's article. DTS on the forums: shown only for push-started activities, and the token waits for Allow. The suggested workaround is to start the first activity locally while the app is in the foreground. |

## 4. Anton's idea: start the Live Activity 30 minutes before kickoff

What it buys: half an hour for her to see the card and tap Allow, and for
the phone to wake the app, so the token is in before the first goal. A
countdown is also a better pre-match card than a static kickoff time.

What it does not fix: a force-quit app still is not woken. A prompt she
ignores is still ignored, just earlier.

Problems:

- **Builds 2.3 and 2.4 kill it.** `syncForegroundActivity` ends every running
  activity whose fixture is not live, and `NS` is not live. If she opens the
  app during the 30 minutes, the card is gone. match-watcher has already set
  `la_started`, so no second start comes at kickoff. 2.2 does not end it.
  The server cannot tell builds apart per token today (but see the User-Agent
  idea in §5, step 2).
- **Old builds' rendering.** The 2.2–2.4 `ContentState` decodes a pre-match
  state fine (unknown keys are ignored; `elapsed`/`clockStart` nil), but it
  shows "0 - 0" over the status label. The label must be relative, such as
  "Before kick-off". A clock time would be in the wrong time zone, because
  Live Activity tokens carry no timezone. New builds can show a countdown from
  a new optional `kickoff` field with `Text(timerInterval:countsDown:true)`;
  old builds ignore the field.
- **Push rules.** The start alert moves from kickoff to T−30.
  - Tier 2+ already get the T−30 kickoff push (`PREKICK_PUSH`), so they would
    get **two alerts in the same minute**. They can only be merged per device
    once a Live Activity token is linked to its install (app build).
  - Light gets no T−30 push today, so this adds a new lock-screen moment for
    her (PUSH_RULES §5 and §1, `verify-push-rules.sh`).
  - Kickoff itself becomes a silent status update unless that update carries
    an `alert`.
- **A postponement or late start** leaves a tokenless pre-match card up until
  it goes stale. Set `stale-date` to kickoff + 15 min on the pre-match start.
- **Lifetime and budget are fine:** T−30 to FT+30 is about 3 h (worst case
  with extra time and penalties about 4 h, inside 8 h), plus one extra
  priority-10 update at kickoff.

**Verdict:** worth doing only together with a new build (step 4), and only if
channels (step 3) turn out to still need Allow. If a channel-started card
updates without Allow, the T−30 start has nothing left to fix, and it costs a
new lock-screen moment.

## 5. The plan, ranked by how fast it fixes the missing updates

| # | Change | Where | Fixes | Old-build risk |
|---|---|---|---|---|
| 1 | **App fix `4ced911`** (done): the foreground sync re-sends any running activity's token the server has not accepted this session; a push-started card with no token after 10 s is replaced by a locally started one, which iOS tokens straight away; once per fixture. | Next build | Every phone where she opens the app during the match. Removes the frozen card for the rest of the game. | None; new build only. |
| 2 | **Know each token's iOS version and build.** In `register_la_token`, read `current_setting('request.headers', true)::json->>'user-agent'`. The app sends URLSession's default `GoalDigger/<build> CFNetwork/… Darwin/<n>` (Darwin 23 = iOS 17, 24 = iOS 18, 25 = iOS 26). Store `os_major` and `build` on the row. Within a day of normal use every active install is known, old builds included. **Check first that Supabase forwards User-Agent into `request.headers`.** | Server only (migration) | Prerequisite for 3 and for the T−30 gating. Also answers "how many are on iOS 17". | None; old builds call the same RPC. |
| 3 | **Broadcast channels for iOS 18+.** Create one channel per fixture at T−60 (policy 0), store it on `match_status_state`. Start iOS ≥ 18 tokens with `input-push-channel`; keep today's payload for iOS 17 and unknown. Updates and the end go out as **one broadcast per change** instead of N sends. Delete the channel after FT + 1 h. Keep the token path for in-app starts (step 1, and the iOS 17 phones). Behind a secret flag, Anton's phone first. | Server; one portal switch (Broadcast Capability) | The token dependency entirely: no app wake, no registration, a force-quit app no longer matters. Also cheaper per goal. | Must test on the App Store binary that a channel start works without any app change (Apple's docs mention only the App ID switch). Unknown: whether an unanswered Allow also holds back channel updates. Test before turning on. |
| 4 | **Add `input-push-token: 1`** to the token start payload for iOS ≥ 18 rows. | Server only | Apple's documented iOS 18 form; forum reports say little effect. | Undocumented on iOS 17; gate on step 2. Moot for rows that move to channels. |
| 5 | **Next build, beyond the fix:** send `install_id` (and the push-to-start token) with every update-token registration, so the server can skip a start for an install that already has an activity; on iOS 26, schedule the activity from Matchday › Before (`request(…, start: kickoff)`, the matchday-reminder tap lands there) so the token exists before kickoff with no Allow prompt; one in-app demo activity in onboarding to settle Allow (DTS's workaround; test that it really stops the prompt); a `kickoff` field and countdown for a pre-match state, and the foreground cleanup leaves a pre-match card alone. | App build + small migration | Prompt and timing for new installs; makes §4 possible. | Additive; old builds ignore new fields. |
| 6 | **T−30 start** (§4). | Server, after 2 + 5 | The Allow window. | High on 2.3/2.4 without build gating. |
| 7 | **Hygiene / measuring.** Log a `la_token_yield` row about 10 min after each start (update tokens ÷ production push-to-start rows seen in the last 30 days). Stop sending to `development` rows older than 14 days, or prune them. | Server | Makes every step above measurable. | None. |

**Top recommendation:** steps 2 and 3. They are server-only apart from one
portal switch, and they remove the dependency on update tokens for every
iPhone on iOS 18 or later, old builds included. Meanwhile ship step 1 in the
next build. Test both unknowns in step 3 on Anton's phone, on a real fixture,
before enabling for everyone.

## 6. Decisions for Anton

1. **Turn on Broadcast Capability** for `com.goaldigger.app` in Certificates,
   IDs & Profiles. Turning it on is harmless. Turning it off later deletes
   every channel, and that cannot be undone.
2. **Store iOS version and build from the User-Agent** in `register_la_token`
   (server-only), or wait for a build that sends them explicitly?
3. **Channels for iOS 18+:** go, behind a flag, Anton's phone first?
4. **T−30 start:** park until channels are measured? If later yes:
   - does the Live Activity start replace the T−30 kickoff push for tier 2+?
   - does Light get an alert at T−30 (a new §1 moment)?
   - does the kickoff update carry its own alert?
5. **Ship `4ced911`** in the next TestFlight build.
6. **Development tokens:** prune the 36 `development` push-to-start rows, or
   keep them for testing?
