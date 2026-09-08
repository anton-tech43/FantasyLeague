# Say This source. Situations: (id, group, label, lines). Lines: (suffix, text, usage, risk, lingo_id or None)
# text ≤60 — lean on a real football saying wherever one exists, and link it to its Lingo entry.
# usage ≤100 — when to say it, and what happens if he asks a follow-up.
# No two lines in a situation start with the same word.

SITUATIONS = [
    ("goal-for-us", "moments", "His team just scored", [
        ("1", "Get in!", "The only correct reaction to a goal. Loud, immediate, no explanation needed.", "safe", None),
        ("2", "Clinical. Absolutely clinical.", "A calm, precise finish rather than a scramble. He'll agree and repeat it.", "bold", "clinical-finish"),
        ("3", "That's been coming.", "If they'd had chances before it went in. Sounds like you were watching properly.", "safe", None),
        ("4", "Top bins!", "Only when it's in the top corner. Anywhere else and it's just loud.", "bold", "top-bins"),
    ]),
    ("goal-against", "moments", "The other lot just scored", [
        ("1", "Nobody picked him up.", "A player was left unmarked. True nearly every time a goal goes in.", "bold", "caught-napping"),
        ("2", "That's a howler from the keeper.", "Only if the goalkeeper clearly dropped it or let it through. Otherwise it's cruel.", "bold", "howler"),
        ("3", "Against the run of play, that.", "When his team had been the better side. The consolation he wants to hear.", "bold", "against-the-run-of-play"),
        ("4", "Loads of time left. Loads.", "Before the hour mark. In the last ten minutes it sounds desperate.", "safe", None),
    ]),
    ("var-check", "moments", "VAR is checking something", [
        ("1", "Here we go. Grab a drink.", "The moment the referee puts a hand to his ear. This will take a while.", "safe", "var"),
        ("2", "If it takes this long it's not clear and obvious.", "After about a minute. It's the rule VAR is meant to follow, and he'll nod.", "bold", "clear-and-obvious"),
        ("3", "They're drawing lines. It'll be an armpit.", "An offside check. Lines on the screen means it's down to millimetres.", "bold", "offside"),
        ("4", "Just give it. Nobody's got a clue.", "Any long check. Half the country is saying the same thing.", "safe", None),
    ]),
    ("red-card", "moments", "Someone got sent off", [
        ("1", "Early bath for him.", "Any red card. Football's phrase for being sent off; he'll like that you know it.", "bold", "early-bath"),
        ("2", "Yellow at most. That's soft.", "A tackle that looked more clumsy than nasty. If he disagrees, ask what made it a red.", "bold", None),
        ("3", "Ten men. Park the bus.", "When it's his team down to ten and ahead or level. Defend, don't attack.", "safe", "park-the-bus"),
        ("4", "He knew the second he did it.", "When the player walks off without arguing.", "safe", None),
    ]),
    ("penalty", "moments", "Penalty", [
        ("1", "Don't look. Just tell me.", "If it's his team taking it. Hands over eyes is optional.", "safe", "penalty"),
        ("2", "Keeper's gone early.", "If the goalkeeper is bouncing off his line before the kick. He can be booked for it.", "bold", None),
        ("3", "Stutter run-up. I hate a stutter run-up.", "When the taker slows down mid-run. A strong opinion that many fans share.", "bold", None),
        ("4", "Bottom corner, please.", "Just before the kick. Low and to a side is the safe finish, and he knows it.", "safe", None),
    ]),
    ("big-save", "moments", "The keeper made a big save", [
        ("1", "How has he kept that out?", "Anything from close range that looked in.", "safe", None),
        ("2", "Worth a goal, that.", "A save late on or when it's tight. He says this too.", "safe", None),
        ("3", "Strong hands. Didn't just parry it.", "When the keeper pushed it wide or over rather than back into play.", "bold", None),
        ("4", "Keeper's earning his money today.", "After the second or third save. Works for either team's keeper.", "safe", "clean-sheet"),
    ]),
    ("subs", "moments", "They're making a substitution", [
        ("1", "Bit early for that?", "A change before the hour when nobody is injured.", "bold", "substitution"),
        ("2", "Fresh legs. Makes sense.", "Any change after seventy minutes.", "safe", None),
        ("3", "He's been hooked. Not his day.", "When the player coming off has had a poor game. Hooked means taken off for playing badly.", "bold", "hooked"),
        ("4", "Who's this coming on?", "The gentle way to get him talking about the squad.", "safe", "the-bench"),
    ]),
    ("injury", "moments", "A player is down injured", [
        ("1", "That doesn't look good.", "When the player stays down and the physio runs on.", "safe", None),
        ("2", "Hamstring. You can tell by the grab.", "When a player pulls up running and holds the back of his thigh. Nine times in ten you're right.", "bold", None),
        ("3", "Give him the magic sponge.", "When it looks minor. The old joke about physios curing everything with a wet sponge.", "safe", "magic-sponge"),
        ("4", "Milking it a bit.", "When they roll around and then jog off. Say it after, not before.", "bold", "dive"),
    ]),
    ("near-miss", "moments", "So close", [
        ("1", "Off the woodwork! So close.", "The ball hit the post or the bar. The whole room groans.", "safe", "hit-the-woodwork"),
        ("2", "Row Z. He's ballooned that.", "A shot that went miles over. Row Z is the back of the stand.", "bold", "row-z"),
        ("3", "That's a sitter.", "An easy chance missed. The one you would have scored, you tell him.", "bold", "sitter"),
        ("4", "Unlucky. Keep going.", "What fans shout after any miss. Means nothing, always fits.", "safe", "unlucky"),
    ]),
    ("scuffle", "moments", "A nasty tackle or a scuffle", [
        ("1", "Handbags. Nothing in it.", "Players pushing and shoving but nobody swinging. It'll be over in ten seconds.", "bold", "handbags"),
        ("2", "That's a booking all day long.", "A late or cynical tackle. He'll be in the book.", "bold", "in-the-book"),
        ("3", "He's gone in two-footed.", "Both feet off the ground in a tackle. Usually a red, and rightly.", "bold", "red-card"),
        ("4", "Ref's going to have a word.", "When the referee calls a player over. Safe, and it's what happens next.", "safe", None),
    ]),
    ("cup-night", "moments", "It's a cup night", [
        ("1", "It's only the League Cup.", "An early round with half the team rested. The line every fan reaches for first.", "safe", "league-cup"),
        ("2", "Any giant-killings on tonight?", "Cup rounds where small clubs are playing big ones. Giant-killing is the upset.", "safe", "giant-killing"),
        ("3", "Cup run! Who've we got next?", "After a win. The draw is the bit he enjoys, so let him tell you about it.", "safe", "the-cups"),
        ("4", "Win this and it's a trip to Wembley.", "A semi-final. A trip to Wembley is fan shorthand for a cup run gone deep.", "bold", "wembley"),
        ("5", "Do they actually want this one?", "When he shrugs at the line-up. Gets him onto which competition matters and why.", "bold", "rotation"),
    ]),
    ("sideways", "how_its_going", "They keep passing it sideways", [
        ("1", "There's no urgency.", "When the ball has gone across the back four three times in a row.", "safe", None),
        ("2", "Someone needs to run at them.", "The other team is sitting deep and nobody is dribbling.", "bold", None),
        ("3", "All possession, no penetration.", "Lots of the ball, no chances. The stat on screen will back you up.", "bold", "possession"),
        ("4", "They're playing in front of them, not through them.", "The ball stays in front of the defence and never goes past it. Pundit-level.", "bold", None),
    ]),
    ("under-pressure", "how_its_going", "His team can't get out of their half", [
        ("1", "Backs to the wall.", "The other team has all the ball and a few corners in a row.", "safe", "backs-to-the-wall"),
        ("2", "Just get a foot on it.", "Everything is frantic and every clearance comes straight back.", "safe", None),
        ("3", "Hoof it if you have to.", "When passing out isn't working. Ugly clearances are allowed now.", "bold", "hoof"),
        ("4", "Half-time can't come quick enough.", "From about the fortieth minute when they're hanging on.", "safe", None),
    ]),
    ("cruising", "how_its_going", "They're winning comfortably", [
        ("1", "Job done. Take a couple off.", "Two or more up with twenty minutes left.", "safe", None),
        ("2", "Don't go to sleep now.", "The classic. Cover for a lead that could still be thrown away.", "safe", "caught-napping"),
        ("3", "Game management now. Keep the ball.", "Slow it down, no risks. He'll approve of the phrase.", "bold", "game-management"),
        ("4", "Get the young lad on.", "When the game is safe and there are kids on the bench.", "bold", None),
    ]),
    ("boring", "how_its_going", "Nothing is happening", [
        ("1", "Both happy with a point here.", "A goalless game where nobody is pushing. Especially late on.", "bold", "nil-nil"),
        ("2", "Someone score, please.", "Any dull stretch. Neutral and honest.", "safe", None),
        ("3", "Game of two halves, hopefully.", "A dull first half. The oldest cliché in football, said with a smile.", "bold", "game-of-two-halves"),
        ("4", "One goal changes this.", "The line that is always true and always sounds wise.", "safe", None),
    ]),
    ("late-drama", "how_its_going", "It's the last ten minutes and it's close", [
        ("1", "Squeaky bum time.", "One goal in it, minutes left. Alex Ferguson's phrase, and everyone knows it.", "bold", "squeaky-bum-time"),
        ("2", "How long has he added?", "As soon as the board goes up. He will tell you to the second.", "safe", "added-time"),
        ("3", "Keep it in the corner. Kill it.", "If his team is a goal up. Boring is good now.", "bold", "see-the-game-out"),
        ("4", "I can't watch this.", "Any tight finish. You are allowed to mean it.", "safe", None),
    ]),
    ("ref-bad", "how_its_going", "The referee is having a bad day", [
        ("1", "He's lost control of this.", "Lots of arguing, players surrounding him, cards flying.", "safe", None),
        ("2", "That's a foul every day of the week.", "When a tackle near the box went unpunished.", "bold", "free-kick"),
        ("3", "Book him then. Be consistent.", "When one side gets a yellow for something the other got away with.", "bold", "yellow-card"),
        ("4", "Nobody came to watch the ref.", "When the referee is the story. Never wrong.", "safe", None),
    ]),
    ("other-lot-winning-ugly", "how_its_going", "The other team is winning ugly", [
        ("1", "Smash and grab, this.", "They've had one chance and scored it while his team did everything else.", "bold", "smash-and-grab"),
        ("2", "They've parked the bus.", "Everyone behind the ball, no attacking at all. The classic complaint.", "safe", "park-the-bus"),
        ("3", "Dark arts. Fair play to them.", "Time-wasting, little fouls, winding people up. Grudging respect is the correct tone.", "bold", "dark-arts"),
        ("4", "Ref, get on with it.", "When the goalkeeper takes forty seconds over every goal kick.", "safe", None),
    ]),
    ("half-time", "when_he_asks", "Half-time and he asks what you think", [
        ("1", "What did you make of it?", "The best tool in this app. Hand the question straight back.", "safe", None),
        ("2", "Better than I expected, honestly.", "If his team is level or ahead against a decent side.", "safe", None),
        ("3", "Need to be braver in the second half.", "If they've been cautious. Vague enough to be true.", "bold", None),
        ("4", "They'll be getting the hairdryer.", "If they were poor. The manager shouting at half-time; Ferguson's speciality.", "safe", "hairdryer"),
    ]),
    ("full-time-win", "when_he_asks", "Full-time, they won", [
        ("1", "Deserved that. Never in doubt.", "A comfortable win. Even if it was a bit in doubt.", "safe", None),
        ("2", "Won ugly, but three points is three points.", "A scrappy win. He's been saying this since he was twelve.", "bold", "points"),
        ("3", "Who's your man of the match?", "Keeps him talking about it in a good mood.", "safe", "man-of-the-match"),
        ("4", "Where are we in the table now?", "He knows already. He wants to be asked.", "safe", "the-table"),
    ]),
    ("full-time-loss", "when_he_asks", "Full-time, they lost", [
        ("1", "That one stings.", "Short and sympathetic. Then leave a pause.", "safe", None),
        ("2", "Robbed. Absolutely robbed.", "Only if a decision went against them. He'll take it from there.", "bold", None),
        ("3", "One of those days. We go again.", "The universal reset button, in the words players use.", "safe", "we-go-again"),
        ("4", "The performance wasn't there.", "If they were bad. Sounds like a pundit, in a good way.", "bold", None),
    ]),
    ("full-time-draw", "when_he_asks", "Full-time, it was a draw", [
        ("1", "Two points dropped.", "If they were the better team or were winning late on.", "bold", "points"),
        ("2", "Take the point and move on.", "If they were hanging on at the end.", "safe", None),
        ("3", "Nobody's happy with that, are they?", "A flat nil-nil. Safe because it is always true.", "safe", "nil-nil"),
    ]),
    ("who-was-good", "when_he_asks", "He asks who you thought played well", [
        ("1", "The keeper. Kept them in it.", "If the score was close and the keeper made a few saves.", "safe", None),
        ("2", "Whoever was running the midfield.", "There is always one. Ask him to name him and agree.", "bold", "box-to-box"),
        ("3", "Honestly, the full-backs. Up and down all day.", "The wide defenders. A slightly expert-sounding pick.", "bold", "full-back"),
        ("4", "You tell me. You watched it properly.", "Hand it back with a compliment attached.", "safe", None),
    ]),
    ("manager-question", "when_he_asks", "He asks what you think of the manager", [
        ("1", "He needs a run of games to judge him properly.", "A newish manager. Fair and unfalsifiable.", "safe", "new-manager-bounce"),
        ("2", "The players seem to be playing for him.", "If they look like they're trying hard. Check first.", "bold", None),
        ("3", "His subs are always a bit late, aren't they?", "A common complaint about nearly every manager. Low risk of being wrong.", "bold", "substitution"),
        ("4", "Do you actually rate him or do you just want him gone?", "When he's been moaning. Makes him decide.", "bold", "sack-race"),
    ]),
    ("big-game-tomorrow", "when_he_asks", "He mentions a big game coming up", [
        ("1", "Who's out injured for it?", "There is always somebody. He'll know the whole list.", "safe", None),
        ("2", "A draw would be fine, wouldn't it?", "If it's away against a bigger team.", "bold", None),
        ("3", "What time is it on? I'll watch the start with you.", "Small offer, big impact.", "safe", "kick-off"),
        ("4", "Proper six-pointer, this.", "Only when both teams are chasing the same thing: the title, top four, survival.", "bold", "six-pointer"),
    ]),
]
