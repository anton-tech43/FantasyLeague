// _shared/concurrency.ts
// Bounded-parallel fan-out for APNs push sending.
//
// Every push sender used to loop `for (…) await sendPushNotification(…)` — one
// HTTP/1.1 round-trip at a time. At 50k users a marquee team's audience blows
// the Edge Function 400s wall-clock ceiling and the loop dies mid-send, so
// recipients past the cutoff silently get nothing. `mapWithConcurrency` keeps a
// fixed pool of sends in flight instead, turning ~minutes of sequential waiting
// into ~tens of seconds. See SCALING_50K.md §1.

/// Default in-flight cap for push fan-out. Conservative for HTTP/1.1 (each slot
/// can hold open a TCP+TLS connection to APNs): 50k / 100 × ~100ms ≈ 50s, well
/// under the 400s ceiling and sub-minute for any realistic single-team audience.
/// Bump it once the client moves to native HTTP/2 (SCALING_50K.md §1.5).
export const PUSH_CONCURRENCY = 100;

/// Run `fn` over `items` with at most `limit` calls in flight at once. Results
/// are returned in input order (slot i holds fn(items[i])). `fn` is expected NOT
/// to throw — the push helpers (`sendPushNotification`/`sendLiveActivityPush`)
/// already catch internally and return result objects; a genuine throw rejects
/// the whole map, same as `Promise.all`.
export async function mapWithConcurrency<T, R>(
  items: readonly T[],
  limit: number,
  fn: (item: T, index: number) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  if (items.length === 0) return results;

  const cap = Math.max(1, Math.min(Math.floor(limit) || 1, items.length));
  let next = 0;

  async function worker(): Promise<void> {
    while (true) {
      const i = next++;
      if (i >= items.length) return;
      results[i] = await fn(items[i], i);
    }
  }

  await Promise.all(Array.from({ length: cap }, () => worker()));
  return results;
}
