// _shared/goal-push-copy.ts
//
// Copy for the live pushes (goal / kickoff-soon / half-time / full-time). The
// goal pools are keyed by score state; half-time and full-time are
// keyed by situation (see HT_COPY / FT_COPY at the end). goal-push.ts picks
// at fire-time, seeded per fixture. Kept apart
// from goal-push.ts so the logic file stays readable and the copy is easy to
// edit in bulk.
//
// Placeholders, filled by goal-push.ts:
//   {team}  the follower's own team    {opp}  the other side
//   {score} follower-first ("their team first"), in every pool: an Arsenal
//           follower at Anfield sees "Arsenal 1-0", never "0-1 to Liverpool".
//
// GOAL pools (rewritten 2026-11-01, app council LOCK-02-01): one short fact,
// keyed by where the goal leaves her team (ahead, level, behind), with the
// scorer and minute leading ("Ødegaard 71'. Arsenal lead 1-0."). The old
// forty-line pools were reactions about him; a goal push is read in one
// glance and the fact is what she wants. No "he/his/him" anywhere.
//
// House rules baked into every line:
//   - NO em-dashes or en-dashes (campaign rule). Hyphens in "half-time" /
//     "full-time" and in scorelines are fine.
//   - Rendered worst-case (longest names + two-digit score) leaves room for
//     the scorer lead within 90 chars. Enforced in goal-push.test.ts.

// ============================================================
// GOAL pools. Keyed by the follower's state after the goal.
// ============================================================

export type GoalState = "ahead" | "level" | "behind";

/// Her team scored.
export const GOAL_SCORED: Record<GoalState, readonly string[]> = {
  ahead: ["{team} lead {score}.", "Goal for {team}. {score} up."],
  level: ["{team} equalise. {score}.", "{team} level it at {score}."],
  behind: ["{team} pull one back. {score}.", "Goal for {team}. Still {score} down."],
};

/// The other side scored.
export const GOAL_CONCEDED: Record<GoalState, readonly string[]> = {
  ahead: ["{opp} pull one back. {team} still lead {score}.", "{opp} score. {team} lead {score}."],
  level: ["{opp} equalise. {score}.", "{opp} level it at {score}."],
  behind: ["{opp} score. {team} trail {score}.", "Goal for {opp}. {team} are {score} down."],
};

/// Both sides scored between two polls.
export const GOAL_BOTH: Record<GoalState, readonly string[]> = {
  ahead: ["Goals at both ends. {team} lead {score}."],
  level: ["Goals at both ends. {score}."],
  behind: ["Goals at both ends. {team} trail {score}."],
};

// ============================================================
// 30-MINUTES-TO-KICKOFF pool. {team} = follower's team, {opp} = opponent.
// No score (the game hasn't started). The "it's about to start" nudge.
// ============================================================

export const KICKOFF_SOON: readonly string[] = [
  "{team} vs {opp} kicks off in 30 minutes. Time to get comfy.",
  "Almost time. {team} take on {opp} in half an hour.",
  "{team} kick off against {opp} in 30. He'll be settling in.",
  "30 minutes until {team} vs {opp}. Last call for snacks.",
  "{team} vs {opp} starts in half an hour. He's on the sofa already.",
  "Nearly kickoff. {team} face {opp} in 30 minutes.",
  "{team} are about to start against {opp}. 30 minutes to go.",
  "Half an hour till {team} vs {opp}. Wish him luck.",
  "{team} vs {opp} in 30. He'll have the telly on already.",
  "Kickoff in 30: {team} vs {opp}. Settle in with him.",
  "{team} play {opp} in half an hour. Game face on.",
  "Not long now. {team} vs {opp} kicks off in 30 minutes.",
];

// ============================================================
// HALF-TIME and FULL-TIME: what kind of game it is, then a line to say
// ============================================================
//
// Rewritten 2026-10-29 (Anton). The old body was a 40-deep pool per result
// about HIS mood ("He's already insufferable", "ask for the favour now"): a
// handful of ideas reworded forty times, "he" even when she follows her dad,
// and "a point apiece" after a cup tie. It is gone. The body is now one short
// line saying what kind of game it was (a comeback, a late winner, a cup
// exit), which only we can write because we hold the half-time score and the
// goal minutes, followed by `Say: "…"`: one line she can say to him.
//
// The half-time and full-time pushes are the two moments with time to talk.
// A goal push arrives a minute or two late; half-time lasts fifteen minutes
// and full-time the rest of the evening (Anton, 2026-10-02).
//
// Rules for the lines to say (goal-push.test.ts sweeps every one):
//   - Her voice to him, first person, "we" for his team. No em-dashes.
//   - At most 60 characters.
//   - Assume nothing about the opponent: "first goal wins this" is only true
//     against some sides. Prefer what OUR team should do.
//   - No "point" or "points": these pools also serve cup ties.
//   - Match the size of the score: a 1-1 is not "nobody can defend".
//   - An opinion about the game, never comfort or an instruction to him
//     ("Forget it. Next week.", "Enjoy every second"): dropped 2026-11-01
//     (LOCK-02-05).
//
// Body placeholders: {score} follower-first, {team} her team, {when} "in the
// 88th minute" / "in stoppage time", {how} "" / " after extra time" /
// " on penalties".

export type HtSituation = "ahead_big" | "ahead_one" | "nil_nil" | "level_goals" | "behind_one" | "behind_big";

export type FtSituation =
  | "win_big" | "win_plain" | "win_narrow" | "win_late" | "win_comeback"
  | "draw_nil" | "draw_goals" | "draw_late_for" | "draw_late_against"
  | "loss_narrow" | "loss_big" | "loss_late"
  | "cup_through" | "cup_out" | "cup_won";

export interface SituationCopy {
  body: readonly string[];
  say: readonly string[];
}

export const HT_COPY: Record<HtSituation, SituationCopy> = {
  ahead_big: {
    body: ["{team} are {score} up at the break.", "{score} up at half-time. A good half's work."],
    say: [
      "Two up. Just don't do anything silly now.",
      "Don't get sloppy after the break.",
      "That's how you start a game.",
      "Keep the ball and let them chase it.",
      "Go for another. Kill it off.",
      "Don't sit back. Keep going at them.",
      "Keep this up and it's done by sixty.",
      "Just need to stay switched on now.",
    ],
  },
  ahead_one: {
    body: ["{team} lead {score} at the break.", "{score} up at half-time. Not safe yet."],
    say: [
      "One goal's never enough. We need a second.",
      "Good half, but one goal is never safe.",
      "Get the next one and it's done.",
      "Don't sit back on one goal.",
      "Keep pressing. The second goal kills it.",
      "Need to stay switched on at the back.",
      "Keep the ball more. Make them run.",
      "Good start. Now finish the job.",
    ],
  },
  nil_nil: {
    body: ["Still goalless at the break.", "0-0 at half-time. Nothing in it yet."],
    say: [
      "We need to shoot more. Make the keeper work.",
      "Need to get more people in the box.",
      "We need to be braver going forward.",
      "Get it wide and get crosses in.",
      "Someone needs to have a go from distance.",
      "Need to move the ball quicker.",
      "Need a bit more urgency second half.",
      "Keep it tight, but we need a goal.",
    ],
  },
  level_goals: {
    body: ["Level at {score} at the break.", "{score} at half-time. All to play for."],
    say: [
      "Proper game, this. Anything could happen.",
      "Good to see us scoring. Now tighten up.",
      "We need to stop giving them chances.",
      "Need to tidy up at the back.",
      "Keep attacking like that, it'll come.",
      "Better than a boring nil-nil.",
      "Next goal is massive.",
      "Fun to watch. Bit nervy though.",
    ],
  },
  behind_one: {
    body: ["{team} trail {score} at the break.", "{score} down at half-time. One goal in it."],
    say: [
      "One goal in it. Plenty of time.",
      "Get the next one and it's a different game.",
      "We've come back from worse. Forty-five minutes.",
      "Need to be braver. Get bodies forward.",
      "Keep calm. No need to rush it yet.",
      "Need a quick start to the second half.",
      "Need to shoot more. Test the keeper.",
      "Stick at it. The chances will come.",
    ],
  },
  behind_big: {
    body: ["{team} are {score} down at the break.", "{score} down at half-time. A tough half."],
    say: [
      "Something has to change at half-time.",
      "We need an early goal after the break.",
      "Long way back. The next goal is huge.",
      "Need a change. Fresh legs, maybe.",
      "Get one back early and it's game on.",
      "Nothing to lose now. Just go for it.",
      "Need to be way more aggressive.",
      "Don't let it get any worse first.",
    ],
  },
};

export const FT_COPY: Record<FtSituation, SituationCopy> = {
  win_big: {
    body: ["Won {score}, and comfortably.", "{team} win {score}. A proper result."],
    say: [
      "Could get used to that.",
      "That's more like it.",
      "Everyone was up for that today.",
      "Proper performance, that.",
      "That's a statement, that.",
    ],
  },
  // A win by two or more when we cannot say when it was decided (the goal
  // list is incomplete, or it went to extra time): no "comfortably".
  win_plain: {
    body: ["Won {score}.", "{team} win {score}."],
    say: [
      "Good win, that.",
      "Job done.",
      "Happy with that.",
      "That's more like it.",
    ],
  },
  win_narrow: {
    body: ["Won {score}. Tight, but a win.", "{team} edge it {score}."],
    say: [
      "Ugly, but we'll take it.",
      "Nervy. But a win's a win.",
      "Didn't enjoy those last ten minutes.",
      "Job done. Not pretty, but job done.",
      "Should've been more. Still, we won.",
      "Hard work, that. Got there.",
      "Those are the ones that matter.",
      "Didn't make it easy for ourselves.",
    ],
  },
  win_late: {
    body: ["Won {score} with a winner {when}.", "{score}, and the winner came {when}."],
    say: [
      "Left it late! My heart can't take that.",
      "That's why you never leave early.",
      "Right at the death. Get in.",
      "Never stopped going. Love that.",
      "Late winners are the best winners.",
      "Thought that was slipping away. Get in.",
      "Scenes! What a finish.",
      "Kept going till the end. Deserved that.",
    ],
  },
  win_comeback: {
    body: ["Behind at the break and won it {score}.", "Came from behind to win {score}."],
    say: [
      "Behind at half-time and won it. Love that.",
      "Whatever was said at half-time worked.",
      "What a second half.",
      "Showed some character there.",
      "Completely different team after the break.",
      "Never gave up. Brilliant.",
      "Comebacks feel twice as good.",
      "Turned it round. Proper fight, that.",
    ],
  },
  draw_nil: {
    body: ["Finished 0-0.", "Goalless at full-time."],
    say: [
      "Not one for the highlights.",
      "Ninety minutes and nothing. Fair enough.",
      "Needed to be braver going forward.",
      "Solid at the back, nothing up front.",
      "At least we didn't concede.",
      "Needed a bit of magic from someone.",
      "Needed more shots, honestly.",
    ],
  },
  draw_goals: {
    body: ["Finished {score}.", "A {score} draw at full-time."],
    say: [
      "Entertaining, at least.",
      "Could've won it, could've lost it.",
      "Fair result, honestly.",
      "Good going forward, sloppy at the back.",
      "Not a bad game to watch.",
      "Happy we scored. Annoyed we conceded.",
      "Mixed feelings on that one.",
      "Either side could've nicked that.",
    ],
  },
  draw_late_for: {
    body: ["Drew {score} with an equaliser {when}.", "Rescued a {score} draw {when}."],
    say: [
      "Snatched it at the end! Never give up.",
      "Feels like a win, that one.",
      "Thought we'd lost that. Get in.",
      "Kept going right to the end.",
      "That's character, that.",
      "Not dead till the whistle.",
      "Late drama. I'll take it.",
      "My heart. Saved it right at the end.",
    ],
  },
  draw_late_against: {
    body: ["Drew {score} after conceding {when}.", "Pegged back {when}. It finished {score}."],
    say: [
      "So close. That one hurts.",
      "Should've seen that out.",
      "Need to learn to see games out.",
      "Thought we had that. Gutted.",
      "Needed to keep the ball at the end.",
      "Feels like a defeat, that.",
      "Need to kill games off earlier.",
      "Minutes from a win. Cruel.",
    ],
  },
  loss_narrow: {
    body: ["Lost {score}.", "Beaten {score}. One goal in it."],
    say: [
      "One goal in it. Annoying.",
      "Need to be more clinical.",
      "Didn't do enough to win, sadly.",
      "Frustrating. Need a goal from somewhere.",
    ],
  },
  loss_big: {
    body: ["Lost {score}.", "Beaten {score}. A tough one."],
    say: [
      "Nothing went right today.",
      "Need a proper reaction next game.",
      "Never got going today.",
      "Too easy for them today.",
    ],
  },
  loss_late: {
    body: ["Lost {score} to a goal {when}.", "Beaten {score}, the winner coming {when}."],
    say: [
      "Losing it that late is the worst.",
      "So close. Cruel, that.",
      "Thought we'd got something. Gutted.",
      "That last goal really hurts.",
      "Need to see games out better.",
      "Minutes from a draw. Painful.",
      "Brutal. Right at the end.",
      "Hate losing like that.",
    ],
  },
  cup_through: {
    body: ["Won {score}{how}.", "{team} win {score}{how}."],
    say: [
      "Through! Who do we get next?",
      "Into the next round. That's all that matters.",
      "Job done. On to the next round.",
      "Love a cup run.",
      "Still in it. Who's next?",
      "Didn't matter how. We're through.",
      "Next round, here we come.",
      "Cup dream's still alive.",
    ],
  },
  cup_out: {
    body: ["Lost {score}{how}.", "Beaten {score}{how}."],
    say: [
      "Out of the cup. All about the league now.",
      "Gutted. Liked having a cup run.",
      "Bit gutted. We'll go again next season.",
      "Wanted a proper cup run this year.",
    ],
  },
  cup_won: {
    body: ["Won the final {score}{how}.", "{team} win the final {score}{how}."],
    say: [
      "What a day. Cup winners!",
      "They'll remember this one forever.",
      "Winners! Nobody can take that away.",
      "A trophy. Doesn't get better than this.",
    ],
  },
};
