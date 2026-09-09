#!/usr/bin/env python3
"""hype_src.py — the lines the app says back to her when a round ends.

Voice: her friend on the sofa. Not a coach, not an app, not a scoreboard.
Second person, present tense, one idea per line, funny before proud. She did
not pick this hobby, so nothing here congratulates her for doing homework —
it tells her what she can now do to him.

Rules the validator enforces (validate_content.py::validate_hype):
  - 90 characters, no em-dashes, at most one "!", unique within a category
  - at least 12 per category
  - none of the gamification vocabulary: level up, awesome, amazing, streak,
    xp, badge, unlock, achievement, congrats
  - the UK idiom banlist, same as every other module

The score is printed by the app above the line ("8 out of 10."), so no line
here states a number. That also keeps every line honest on a three-question
retry round, where "ten for ten" would be a lie.

Twelve per category is the first drop, so Anton can read the tone in the app.
Fifty per category after his nod, same file, same validator, published as a
content version with no app release.
"""

# perfect — every question in the round, however long the round was.
PERFECT = [
    "Not one wrong. Sit next to him tonight.",
    "All of them. Try to look surprised when it comes up.",
    "Clean sweep. He has no idea what's coming.",
    "Every single one. Quietly devastating.",
    "Full marks. Say nothing and let it land later.",
    "No misses. Ask him the same questions and watch.",
    "You got the lot. You're the one explaining it now.",
    "Flawless. Drop one of these at half time.",
    "Nothing missed. That's a bit rude, honestly.",
    "All correct. He thinks you're just being polite.",
    "Perfect round. Save it for when the telly's on.",
    "Not a single miss. You know his team better than his mates do.",
]

# strong — 7 to 9 of ten.
STRONG = [
    "Nearly the lot. The ones you missed are the good gossip anyway.",
    "That's more than his mates know.",
    "Almost clean. Nobody at the pub is checking your working.",
    "Solid. That's a whole half of conversation covered.",
    "Just a couple got you. Everyone drops those.",
    "Strong round. He'd have missed two as well.",
    "Close to the full set. Go again and finish the job.",
    "That'll do nicely. You're past the polite-nodding stage.",
    "Good round. The gaps are small and they're fixable.",
    "Nearly all of them. Quietly excellent.",
    "You're properly in this now. He's going to notice.",
    "Comfortable. The ones you lost are the fun ones to learn.",
]

# mid — 4 to 6 of ten.
MID = [
    "Half a pub quiz team already.",
    "Halfway there. The other half is one more round.",
    "Middle of the table. Respectable, room to climb.",
    "Not bad for someone who didn't pick this hobby.",
    "You're getting the shape of it. Keep going.",
    "Some in, some out. That's how everyone starts.",
    "Enough to follow the conversation. Not enough to win it yet.",
    "Halfway. He took years to get here, in fairness.",
    "Decent chunk. The rest sticks faster than you'd think.",
    "You knew more than you thought you would.",
    "Fine start. One more round and this stops being work.",
    "Right in the middle. Nothing embarrassing about that.",
]

# rough — 0 to 3 of ten.
ROUGH = [
    "That's more than yesterday.",
    "Rough one. The answers are right there, go again.",
    "Nobody's watching. Straight back in.",
    "Brutal round. They get easier once the names stick.",
    "Everyone's first go looks like this.",
    "Not your round. The names are the hard part.",
    "Fine. Now you've seen them once, which is the whole trick.",
    "Ugly, but you learned something in every wrong one.",
    "Tough. Read the misses and take it again.",
    "He'd have got these wrong too, at the start.",
    "One more go and half of those will land.",
    "Bad round, easy fix. They're all in the list below.",
]

# streak — three, six or nine correct in a row, mid-round.
STREAK = [
    "Three in a row. Who's the fan now.",
    "You're on a run. Don't tell him.",
    "Three straight. Keep going, quietly.",
    "Nobody's stopping you. Next.",
    "Three on the bounce. Suspicious.",
    "That's a run. Ride it.",
    "Back to back to back. Casual.",
    "You're just doing these now.",
    "Three clean. He'd be annoyed.",
    "On a roll. Don't look down.",
    "Three right. Someone's been paying attention.",
    "Rolling. Next one's yours as well.",
]

CATEGORIES = {
    "perfect": PERFECT,
    "strong": STRONG,
    "mid": MID,
    "rough": ROUGH,
    "streak": STREAK,
}
