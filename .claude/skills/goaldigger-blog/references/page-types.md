# Page types

Four kinds of page. Each has a search reason, a skeleton, and the one thing only we can put in it. If a page can't name its "only we" item, don't write it yet.

All pages: sentence-case headline that says plainly what the page is (that is the SEO bit); the voice lives in the body. One App Store link, near the end, one sentence, no pitch. Published date and "updated" date visible. Draft only from a facts block (see SKILL.md).

## 1. Club for beginners

**Search reason:** "Leeds United for beginners", "who are Arsenal", "what to know about [club]".
**Title shape:** `[Club] for beginners` (add a short plain subtitle in the meta description, not the H1).
**Only we have:** the verified manager, current form and league position from the facts block, the rival and why, and one line she can say out loud.

Skeleton (cut anything that doesn't earn its place; this is not a template to fill):
1. One concrete opening moment about him and the club. 12 to 20 words. No definition.
2. Where they are now: position, points, form. Numbers from the block only.
3. The rival and why, in two or three sentences.
4. The manager, in one sentence she could repeat at the pub.
5. What he gets emotional about (the ground, a year, a player), as a tease.
6. Ending: a small turn or a deflating line. Not a recap.

Refresh: every one of these goes stale. Put the data date in the page, and rewrite on the stale-data cadence (after each window, manager change, promotion or relegation).

## 2. Match preview

**Search reason:** "Arsenal vs Leeds what to know", "[club] v [club] preview for beginners".
**Title shape (H1):** `[Club] v [club] for people who don't follow football`. Title tag: `[Club] v [club] for beginners: what to know before kick-off`. Day, time, venue and "Premier League" in the first paragraph. H2s are her questions, not a fan's: "Is it a big one?", "Who's going to win?", "What should I say to him?". No team news section; she isn't searching for it.
**Only we have:** the head-to-head from the block (the real scores, summed), both teams' form, the one thing to ask him, and the one thing to say.

Skeleton (this is a person talking, not a fact sheet; the first version of this page was all facts and Anton called it out):
1. The match in one sentence, with the day.
2. **The obvious read**, then **why she doesn't quite buy it**, built from numbers she went and looked at (league-wide: who scores most, who concedes least, who beat whom last time). This is her take.
3. The history, with the real figures, as something she reacts to rather than lists.
4. **A guess at the result**, labelled as a guess, with a light joke about not repeating it.
5. **Who do I need to know:** two names per team (Anton: "easy and valuable"). Take them from the squad table (`players`, `in_official_squad`, stats date checked), not from routine one-liners. Say what the *position does* in plain words (midfielder: plays in the middle and does the passing; goalkeeper: the one in gloves). One number per player at most. Choose names that serve the post's take (the goalkeeper for a post about a defence).
6. **What can I say to him:** a short, usable list of lines and mostly **questions**, grouped by before kick-off, during, and after (with a line for each outcome, including "his team lose"). Every line must be true on the facts block and answerable by someone who knows the game. One headline line first (the true, slightly unexpected one). A bullet list is allowed here because the lines are genuinely a list; keep lines short, no bold labels.
7. A line or two on what to expect him to do or say (a shape, a set-piece strength), with honest ignorance if she half-gets it.
8. Ending on a plain fact or a small observation. Not a question to ask him every time.

Facts block marks the take: `OPINION, not fact: …`.

Pace: previews are the most time-bound pages. Publish the day or two before, not weeks ahead. Add a "result" line afterwards or let it age out.

## 3. Explainer (evergreen)

**Search reason:** "what is offside", "what does xG mean", "why is there VAR", "how does relegation work".
**Title shape:** `Offside, explained` (plain).
**Only we have:** the explanation as a newcomer actually needs it, using one thing from her world, and the line that lets her use it tonight.

Skeleton:
1. The moment the word comes up (he shouts it). One sentence.
2. The honest short answer, in the words a newcomer would use, then the proper term once.
3. One everyday UK comparison (see voice-traits: pick the domain she already knows). Never a sports metaphor.
4. The argument people actually have about it (this is the real content; the rule alone is on every page).
5. What to say. One line.

Reality check: this is the most competitive page type (everyone has an offside explainer). Only write it if the angle is different. "What to say when he complains about it" is different. "A complete guide to the offside rule" is not.

## 4. Relationship piece

**Search reason:** "boyfriend only talks about football", "how to get into football for him", "football widow".
**Title shape:** plain and human, e.g. `He's gone quiet at half-time. Here's what's happening.`
**Only we have:** the app's whole premise: she doesn't have to become a fan.

Skeleton:
1. A small real scene, specific time and object.
2. What's actually going on with him (affectionate, a little dry).
3. What helped, in first person, flat. Hedge the football, commit on the feeling.
4. One thing to try this weekend.
5. Ending: a shrug or a small joke.

These rarely rank but they get shared. Keep them few. Don't pitch the app inside the story; one plain link at the end.

## Pacing (scaled-content guard)

Start with 5 club pages and 3 previews. Watch Search Console for 6 to 8 weeks. Publish more of whatever gets impressions. Never publish a whole batch of near-identical pages at once, and never generate pages by looping a model over teams (CLAUDE.md hard rule: that burns the API credit balance; draft in-session).
