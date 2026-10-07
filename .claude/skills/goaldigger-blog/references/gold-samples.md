# Gold samples

Three things in this file: (1) lines from GoalDigger's own copy that hit the voice, copied in as text, (2) three finished pilot posts with their facts blocks and lint results, (3) a slot for real exemplars. Nothing here is linked to its source; if the source changes, this copy does not.

## 1. Lines that already sound right (copied 2026-10-02 from GoalDigger's brand and ad copy)

Use them to tune your ear, not as a quarry. Don't reuse them verbatim in posts: a post made of the brand's slogans is the "template" problem again.

- He's been refreshing the same transfer rumour for three hours. I've already read the summary. We're fine.
- They lost. 2-0. Not pretty. Tonight's vibe: keep it light, maybe suggest his favourite food.
- She asked if I watched the match. I said I caught the highlights. I had not watched the match.
- He says they "parked the bus". No bus was involved.
- I have been told this is a must win. It is September.
- Tonight's forecast: tense, with a chance of silence.
- He will not hear me until Tuesday.
- He started explaining offside to me. I let him finish.
- He will be quiet for twenty minutes. This is normal.
- Ask him about the new signing. He's been waiting for someone to ask.
- Pre-pour his drink. Tell him you saw the score.

What they share: a plain small situation, a specific object or number, dry delivery, and **no explanation of the joke**. Note the difference from the blog: these are ad-length and speak *as* her in short bursts. The blog has to carry a scene and a fact for 200+ words without the video or the layout to help.

## 2. Pilot posts (2026-10-02)

All three are drafts for a human read, not published. Each was linted (`node lint/blog-lint.mjs post.md --facts facts.txt`) with **0 errors**; remaining warnings are listed. Every sentence about a fixture, score, manager or player traces to its facts block.

### 2a. Match preview: Arsenal v Leeds

**Facts block** (read 2026-10-02 from `team_pages` for leeds and arsenal, and `teams.manager_name`, verified 2026-09-23):

```
Read 2026-10-02 from team_pages (leeds, arsenal) and teams.manager_name (verified 2026-09-23).
Fixture: Arsenal v Leeds, Premier League, Saturday 10 October 2026, 12:30 UK time (11:30 UTC), at Arsenal's ground, Emirates Stadium, London. Round 6.
Table: Leeds 5th, Arsenal 2nd, three points between them. Leeds 9 points from 5 games: 2 wins, 3 draws, 0 losses. Arsenal 12 points from 5 games: 4 wins, 1 loss.
Head to head, five most recent meetings, all won by Arsenal: Leeds 0-4 Arsenal (31 Jan 2026); Arsenal 5-0 Leeds (23 Aug 2025); Arsenal 4-1 Leeds (1 Apr 2023); Leeds 0-1 Arsenal (16 Oct 2022); Arsenal 2-1 Leeds (8 May 2022). Goals across the five: Arsenal 16, Leeds 2.
Managers (teams table): Daniel Farke, Leeds, since 4 July 2023. Mikel Arteta, Arsenal, since 22 December 2019.
Players: Dominic Calvert-Lewin, Leeds striker, three Premier League goals this season (four in all competitions). Bukayo Saka, Arsenal, three Premier League goals in five games.
App talking point (team data): Ask him where he thinks the Arsenal game gets decided. Leeds fifth without losing a game.
```

**Post:**

> # Arsenal v Leeds: what to know before kick-off
> 
> Saturday 10 October, 12:30, at Arsenal's ground, the Emirates. So it's Leeds who are travelling.
> 
> Leeds are fifth on nine points, and they haven't lost yet this season: two wins, three draws. Arsenal are second, three points ahead. The Emirates is the first real test of that unbeaten run.
> 
> The history is the awkward bit. These two have met five times lately and Arsenal won all five, scoring 16 goals to Leeds's 2. The last one was Leeds 0, Arsenal 4, in January. If he brings that up, let him.
> 
> Two names to hold on to. For Leeds, Calvert-Lewin, the striker, with three Premier League goals so far this season. For Arsenal, Saka, who has three in five games.
> 
> The managers are Daniel Farke at Leeds, there since July 2023, and Mikel Arteta at Arsenal, since December 2019.
> 
> One question that will do: where does he think this one gets decided?
> 
> ---
> 
> GoalDigger explains the match in plain English before kick-off. It's on the App Store.

Lint: 0 errors, 0 warnings.
**Before publishing:** the post goes stale after the match; the table, goals and form need refreshing, and the "Calvert-Lewin three goals" and "Saka three in five games" lines come from routine-written player one-liners, so verify them against the squad tables first (DATA_SOURCES.md says routine prose is not a fact source).

### 2b. Evergreen explainer: Offside

**Facts block.** Written by the model from memory. **It has not been checked against the IFAB Laws of the Game. Do not publish until a human checks each line.** The first blind read flagged exactly the points where this kind of summary goes wrong (toe/arms, "standing there", the goalkeeper case).

```
Law 11 (Offside), summarised by the model from memory, NOT yet checked against the IFAB Laws of the Game text. CHECK EVERY LINE BEFORE PUBLISHING.
A player is in an offside position if any part of the head, body or feet is in the opponents' half and nearer to the opponents' goal line than both the ball and the second-last opponent. Hands and arms are not considered; the upper boundary of the arm is in line with the bottom of the armpit. The goalkeeper counts as an opponent. Being level with the second-last opponent is not offside. Position is judged at the moment the ball is played by a teammate. Being in an offside position is not an offence in itself; the player must become involved in active play. No offside offence from a goal kick, throw-in or corner kick. A player cannot be offside in their own half.
Video replay (VAR) is used to check offside by drawing lines on screen.
```

**Post:**

> # Offside, explained
> 
> He'll shout it at some point this weekend. Probably at a man who can't hear him.
> 
> Here's the short version. A player is offside if, at the moment a teammate passes the ball, they're nearer the other team's goal than the ball and nearer than the second-last defender. The goalkeeper counts as a defender, so most of the time that means "ahead of the last outfield player". Level with them is fine.
> 
> Think of queue-jumping: you've pushed in front of the last person before it was your turn. Being in that spot isn't an offence by itself, though. It only counts if you then get involved in the play. And you can't be offside in your own half, or from a throw-in, a goal kick or a corner.
> 
> Is a toe offside? Yes. Head, body and feet all count. Arms don't, and the line is drawn from the bottom of the armpit, which is the kind of detail that starts a row.
> 
> Was he actually involved in the play? That's what the argument is usually about, and it tends to carry on into the next attack.
> 
> Then VAR, the video replay, where someone draws lines on the screen and a goal is ruled out by a few inches. It's a big part of why the rule feels harder than it is.
> 
> A question worth having ready: was he interfering with play, though?

Lint: 0 errors. Warnings: one "A, B and C" list (throw-in, goal kick, corner: three real things, left as is) and no app link (the page type is evergreen; add the footer line if wanted).

### 2c. Relationship piece: half-time

**Facts block:** none needed (no figures or names). Claims are general tendencies and are hedged with "usually".

**Post:**

> # He's gone quiet at half-time. Here's what's happening.
> 
> Nothing's wrong with you.
> 
> Usually his team are either losing, or winning by so little it doesn't feel like winning. Either way he's playing the second half in his head already. Quietly, because saying it out loud might jinx it.
> 
> So don't ask what's wrong. Don't ask what the score is either, it's in the corner of the screen and he knows you can see it. Bring tea. Don't make it a thing.
> 
> If you do want to say something, try "they'll sort it out in the second half." It isn't tactical advice. It's just what every fan wants to hear and will pretend not to need. He'll nod.
> 
> By full-time he'll be back, either delighted or in a different kind of quiet. You'll know which pretty quickly.
> 
> The second one is easier than it looks. Leave him to it, and ask about it on Monday, when he's ready to explain the whole thing from the first minute with the help of a salt shaker.
> 
> ---
> 
> GoalDigger tells you what's going on before kick-off, so you're not guessing from his face. It's on the App Store.

Lint: 0 errors. One "A, B and C" warning (losing, winning narrowly, thinking: it's two options, the list is in the scene, left as is).

## 3. What the blind reads said (2026-10-02)

Method: each post was given to two fresh reader agents (a UK woman of about 28 who doesn't follow football, and a sceptical commissioning editor) with no hint of which texts were which. Mixed into each set were two **controls**: the same facts written the way I'd write without this skill (bold labels, "promises to be a fascinating clash", a conclusion and a pitch).

| | Controls (no skill) | Pilots |
|---|---|---|
| Round 1, reader as UK woman | AI, confidence 5 and 5 | Person 4, person 3, unsure 2 |
| Round 1, editor | AI 5 and 5 | AI-assisted 3 to 4 |
| Round 2 (after fixes), reader | AI 5 and 5 | Person 4, 4, 3 |
| Round 2 (after fixes), editor | AI 5 and 5 | AI-assisted but edited, 3, 3, 4 |

**Caveat on round 2:** the readers saw the draft *before* the last round of edits (the edits above were made in response to them). The final texts in section 2 were linted but **not re-read by a panel**. Re-run a blind read before treating them as final.

**What this proves:** the skill moves text from "obviously AI" to "plausibly a person, probably edited".
**What it does not prove:** that real people or any detector will agree. The readers are the same model family as the writer. No human has rated these. Treat it as a regression test for obvious tells, not a verdict.

What round 1 caught that no word list would, now built into `lint/blog-lint.mjs` and `ai-tells.md` section 2b: aphorism pairs, signpost sentences, stock closers, invented precision ("about four minutes"), generic "he'll…" stated as fact, reassure-then-explain, wink asides, labelled "Ask him / Say this" slots, data dumps with jokes sprinkled in, and a garbled factual simplification.
What round 2 still flagged after the fixes (and what was done): tidy last lines (shortened; two posts now end on a plain question or a flat line), forced casual asides such as "Which is ages, in football" (removed), the app plug sitting inside the story (moved to a clearly separate footer line), "the video replay" where a newcomer would say VAR (changed).
Still open: the same "one question to ask him" move closes two of the three posts, and a sharp reader of the whole series would see a template. Vary the ending across pages.

## 4. Real exemplars (add yours here)

Paste 5 to 20 real texts that sound exactly right: your own messages, a friend's, a user's, a post you wish you'd written. One line on who and where, no names. Then re-measure sentence length and fragment share and adjust `voice-traits.md` and the thresholds in `lint/blog-lint.mjs`.

*(empty)*
