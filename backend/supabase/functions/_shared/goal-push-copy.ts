// _shared/goal-push-copy.ts
//
// Copy for the live pushes (goal / kickoff-soon / half-time / full-time). The
// goal pools hold 40 variants per perspective; half-time and full-time are
// keyed by situation (see HT_COPY / FT_COPY at the end). goal-push.ts picks
// at fire-time, seeded per fixture. Kept apart
// from goal-push.ts so the logic file stays readable and the copy is easy to
// edit in bulk.
//
// Placeholders, filled by goal-push.ts:
//   {flag}  scorer's flag emoji        (goal pools only)
//   {team}  scorer's short name        (goal pools); follower's own team (HT/FT)
//   {score} scoreline. GOAL pools: home-away (matches the title). HT/FT pools:
//           follower-first ("their team first"), e.g. a 0-2 trailer sees "0-2".
//   {home} {away}  short names         (GOAL_BOTH only)
//
// GOAL pools (rewritten 2026-09-09): the scorer and minute now LEAD the body
// ("Ødegaard 71'. ..."), so a line is a reaction, not a report, and stays
// under 60 chars so the whole body fits 90 with the longest lead. Five of the
// old forty said "he's buzzing" and thirty said "text him"; a phone that gets
// three goals in a night heard the same sentence three times. Each phrase
// appears once now, and the pick is seeded per fixture and score.
//
// House rules baked into every line:
//   - NO em-dashes or en-dashes (campaign rule). Hyphens in "half-time" /
//     "full-time" and in scorelines are fine.
//   - Rendered worst-case (longest names + tag-flag + two-digit score) stays
//     <=90 chars. Enforced by the sweep in goal-push.test.ts.
//   - Voice (goal pools): gf-to-bf older-sister, dry and warm. Scorer
//     celebrates, conceder is muted and kind.

// ============================================================
// GOAL pools. {flag}/{team} = the SCORER. {score} = home-away.
// ============================================================

export const GOAL_SCORED: readonly string[] = [
  "{team} score, {score}. He is off the sofa.",
  "{score} to {team}. Whatever you were saying can wait.",
  "Get in. {team} lead {score} and he knows it.",
  "{team} score! {score}. Expect a text before you send one.",
  "That's {score}. He will replay this one all week.",
  "{team} make it {score}. The room just got louder.",
  "Goal, {team}. {score}. Say the scorer's name back to him.",
  "{score}. He has the grin. Ask him who scored.",
  "{team} strike, {score}. Good time to appear with a drink.",
  "{team} are winning {score}. Tell him you saw it.",
  "{score} to {team}. He called it, apparently.",
  "Goal for {team}, {score}. He is hugging a stranger.",
  "{team} score. {score}. Ask him if that was a good one.",
  "{score}. Somewhere he is clapping at a television.",
  "{team} lead {score}. He will talk about the pass.",
  "{team} go {score}. Send the goal emoji, nothing else.",
  "{team} score, {score}. Not the time to ask about dinner.",
  "{score} to {team}. He is texting his mates. Beat them.",
  "Goal, {team}! {score}. Tell him you were watching.",
  "{team} make it {score}. His night just turned.",
  "{score}. He has stood up and he is not sitting down.",
  "{team} strike, {score}. Ask him to explain it later.",
  "{team} score. {score}. A heart is enough.",
  "That's {team}, {score}. Whatever he said, he was right.",
  "{score}. He is going to say 'told you'. He did not.",
  "{team} score, {score}. Big smile, small ask: who was it?",
  "Goal. {team} {score}. He heard the roar first.",
  "{team} ahead, {score}. Ask him if that was the plan.",
  "{score} to {team}. He is doing the little run.",
  "{team} score! {score}. Two words: nice one.",
  "{team} make it {score}. He wanted this one badly.",
  "{score}. He is on his feet, and so is half the street.",
  "Goal for {team}. {score}. Tell him you got there first.",
  "{team} score, {score}. Ask him to send you the clip.",
  "{team} lead {score}. He will need a minute of pure joy.",
  "{score} to {team}. He is a man at peace, briefly.",
  "{team} score. {score}. Say one thing tonight: this.",
  "Goal, {team}. {score}. That is the sound you just heard.",
  "{team} go {score}. He is buzzing. Yes, that is the word.",
  "{score}. Somebody give that man a hug, ideally you.",
];

export const GOAL_CONCEDED: readonly string[] = [
  "{team} score. {score}. Give him a minute.",
  "{score} to {team}. Not the time for a question.",
  "{team} make it {score}. He has gone quiet. Let him.",
  "Goal, {team}. {score}. Tea, not talk.",
  "{score}. He is blaming somebody. Let him finish.",
  "{team} strike, {score}. A hand on the shoulder, no words.",
  "{team} score. {score}. He will say 'typical'. Agree.",
  "{score} to {team}. Put the kettle on and say nothing.",
  "{team} lead {score}. Not the moment for the dishes chat.",
  "Goal for {team}. {score}. Give him five minutes.",
  "{team} score, {score}. Sit down next to him. That is all.",
  "{score}. He is staring at the television. It is not personal.",
  "{team} make it {score}. Save the jokes for tomorrow.",
  "{team} strike. {score}. He is replaying it. Let him.",
  "{score} to {team}. A nod is the right amount of talking.",
  "Goal, {team}. {score}. He is not annoyed with you.",
  "{team} score. {score}. Ask nothing until the restart.",
  "{team} ahead, {score}. He wants it back. Wait.",
  "{score}. He is quiet for now. It passes.",
  "{team} score, {score}. This is the deep breath part.",
  "Goal for {team}, {score}. Be around, not on.",
  "{team} make it {score}. He has views on the referee.",
  "{score} to {team}. Not the moment. In ten minutes, maybe.",
  "{team} strike, {score}. The muttering is not at you.",
  "{team} score. {score}. A biscuit fixes a lot.",
  "{score}. He knew this was coming, he will say. He did not.",
  "Goal, {team}. {score}. Sit tight. Plenty of time left.",
  "{team} lead {score}. Do not mention the last one.",
  "{team} score, {score}. He is calm on the outside only.",
  "{score} to {team}. The remote is safe. Probably.",
  "{team} make it {score}. Now is the time for quiet company.",
  "Goal for {team}. {score}. He wants a goal, not advice.",
  "{team} score. {score}. Let the sigh happen.",
  "{score}. His face says it all. Yours should say nothing.",
  "{team} strike. {score}. Skip the 'it's only a game'.",
  "{team} ahead, {score}. He needs a comeback, not a chat.",
  "Goal, {team}. {score}. Just be there.",
  "{score} to {team}. He will say it is fine. Not yet.",
  "{team} score, {score}. Speak after the next attack.",
  "{team} make it {score}. Small kindness, big effect.",
];

export const GOAL_BOTH: readonly string[] = [
  "It's {score} between {home} and {away}. Goals flying in!",
  "End to end stuff, {home} and {away} at {score}. Chaos!",
  "{score}! {home} and {away} are trading goals. What a game.",
  "Both teams scoring, {score}. {home} vs {away} is wide open.",
  "Goals galore! {home} {score} {away}. This one's a thriller.",
  "{score} and counting. {home} and {away} can't stop scoring.",
  "What a match, {home} {score} {away}. Goals at both ends.",
  "It's {score}! {home} and {away} are putting on a show.",
  "Mad game. {home} {score} {away}. Neither side wants to defend.",
  "Goals flying in, {score}. {home} and {away} are going for it.",
  "{score}! End to end between {home} and {away}. Edge of your seat.",
  "Both nets bulging, {home} {score} {away}. Proper entertainment.",
  "It's basketball out there, {score}. {home} and {away} trading blows.",
  "{home} {score} {away} and the goals keep coming. What a watch.",
  "Wild one, {score}! {home} and {away} both finding the net.",
  "Goals everywhere, {home} {score} {away}. This game has it all.",
  "{score} already! {home} and {away} are not holding back.",
  "Trading goals, {home} {score} {away}. Hope his heart can take it.",
  "It's {score}! Defences optional in {home} vs {away}.",
  "Helter skelter, {home} {score} {away}. Goals at a rate of knots.",
  "{score} and rising. {home} and {away} are putting on a clinic.",
  "Both teams at it, {score}. {home} vs {away} is pure chaos.",
  "Goal fest! {home} {score} {away}. He'll be loving this one.",
  "It's {score}! {home} and {away} keep answering each other.",
  "What a spectacle, {home} {score} {away}. Goals galore.",
  "{score}! Neither {home} nor {away} can stop scoring tonight.",
  "End to end again, {home} {score} {away}. Breathless stuff.",
  "Goals raining down, {score}. {home} and {away} both on it.",
  "It's a shootout, {home} {score} {away}. Edge of the sofa time.",
  "{score} and open as you like. {home} vs {away} is bonkers.",
  "Both finding the net, {home} {score} {away}. Some game this.",
  "Goals, goals, goals. {home} {score} {away}. He's glued to it.",
  "It's {score}! {home} and {away} have thrown the script away.",
  "Frantic stuff, {home} {score} {away}. Goals flowing both ways.",
  "{score}! Toe to toe, {home} and {away}. What a contest.",
  "Both teams firing, {home} {score} {away}. Tell him not to blink.",
  "It's wild, {score}. {home} and {away} trading punches.",
  "Goals everywhere you look, {home} {score} {away}. Brilliant.",
  "{score} and end to end. {home} vs {away} is a proper watch.",
  "Madness, {home} {score} {away}. Both nets getting plenty of action.",
];

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
//
// Body placeholders: {score} follower-first, {team} her team, {when} "in the
// 88th minute" / "in stoppage time", {how} "" / " after extra time" /
// " on penalties".

export type HtSituation = "ahead_big" | "ahead_one" | "nil_nil" | "level_goals" | "behind_one" | "behind_big";

export type FtSituation =
  | "win_big" | "win_narrow" | "win_late" | "win_comeback"
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
      "Told you. Never in doubt.",
      "Easy in the end.",
      "Could get used to that.",
      "That's more like it.",
      "Sit back and enjoy that one.",
      "Everyone was up for that today.",
      "Proper performance, that.",
      "That's a statement, that.",
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
      "One of those. Move on.",
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
      "Not our day. Next one.",
      "Close, but no. On to the next.",
      "One goal in it. Annoying.",
      "Need to be more clinical.",
      "Fine margins. Next one.",
      "Didn't do enough to win, sadly.",
      "Frustrating. Need a goal from somewhere.",
      "Shake it off. Next game.",
    ],
  },
  loss_big: {
    body: ["Lost {score}.", "Beaten {score}. A tough one."],
    say: [
      "Let's not talk about that one.",
      "Gutted. Forget that one.",
      "Forget it. Next week.",
      "One of those days. Move on.",
      "Nothing went right today.",
      "Need a proper reaction next game.",
      "Delete that one from memory.",
      "Bad day. It happens to everyone.",
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
      "Never mind. One less thing to worry about.",
      "Gutted. Liked having a cup run.",
      "Focus on the league now.",
      "Out. At least it frees up the schedule.",
      "Shame. Next year.",
      "Cup's gone. League's what matters.",
      "Bit gutted. We'll go again next season.",
    ],
  },
  cup_won: {
    body: ["Won the final {score}{how}.", "{team} win the final {score}{how}."],
    say: [
      "Cup winners! Enjoy every second of this.",
      "Trophy! Get the champagne out.",
      "What a day. Cup winners!",
      "They'll remember this one forever.",
      "Silverware! I'm so happy for you.",
      "Winners! Nobody can take that away.",
      "A trophy. Doesn't get better than this.",
      "Get the open-top bus ready.",
    ],
  },
};
