# Say This source. Situations: (id, group, label, lines). Lines: (suffix, text, usage, risk, lingo_id or None)
# text ≤60 — lean on a real football saying wherever one exists, and link it to its Lingo entry.
# usage ≤100 — WHEN the line fits, and nothing else. Never what he will do, feel or
#   want to hear, and never how to handle him (MY-12-07, 2026-11-01).
# No two lines in a situation start with the same word. A struck line's id is not
# reused, so a line she starred never turns into different words.

SITUATIONS = [
    ("goal-for-us", "moments", "His team just scored", [
        ("1", "Get in!", "The second it goes in.", "safe", None),
        ("2", "Clinical. Absolutely clinical.", "After a calm, precise finish rather than a scramble.", "bold", "clinical-finish"),
        ("3", "That's been coming.", "When they'd had chances before it went in.", "safe", None),
        ("4", "Top bins!", "Only when it goes in the top corner.", "bold", "top-bins"),
    ]),
    ("goal-against", "moments", "The other lot just scored", [
        ("1", "Nobody picked him up.", "When the scorer was left unmarked.", "bold", "caught-napping"),
        ("2", "That's a howler from the keeper.", "Only if the keeper clearly dropped it or let it through.", "bold", "howler"),
        ("3", "Against the run of play, that.", "When his team had been the better side until then.", "bold", "against-the-run-of-play"),
        ("4", "Loads of time left. Loads.", "Before the hour mark. Not in the last ten minutes.", "safe", None),
    ]),
    ("var-check", "moments", "VAR (the video referee) is checking something", [
        ("1", "Here we go. Grab a drink.", "When the referee puts a hand to his ear and the check starts.", "safe", "var"),
        ("2", "If it takes this long it's not clear and obvious.", "When the check has gone on for about a minute.", "bold", "clear-and-obvious"),
        ("3", "They're drawing lines. It'll be an armpit.", "When the screen shows lines for an offside check.", "bold", "offside"),
        ("4", "Just give it. Nobody's got a clue.", "Any check that drags on.", "safe", None),
    ]),
    ("red-card", "moments", "Someone got sent off", [
        ("1", "Early bath for him.", "Any red card.", "bold", "early-bath"),
        ("2", "Yellow at most. That's soft.", "When a red is given for a tackle that looked clumsy, not nasty.", "bold", None),
        ("3", "Ten men. Park the bus.", "When his team are down to ten and ahead or level.", "safe", "park-the-bus"),
        ("4", "He knew the second he did it.", "When the player walks off without arguing.", "safe", None),
    ]),
    ("penalty", "moments", "Penalty", [
        ("1", "Don't look. Just tell me.", "When his team are taking it.", "safe", "penalty"),
        ("2", "Keeper's gone early.", "When the keeper is off his line before the kick.", "bold", None),
        ("3", "Stutter run-up. I hate a stutter run-up.", "When the taker slows down mid run-up.", "bold", None),
        ("4", "Bottom corner, please.", "Just before his team's taker shoots.", "safe", None),
    ]),
    ("big-save", "moments", "The keeper made a big save", [
        ("1", "How has he kept that out?", "After a save from close range that looked in.", "safe", None),
        ("2", "Worth a goal, that.", "After a big save late on, or with the score tight.", "safe", None),
        ("3", "Strong hands. Didn't just parry it.", "When the keeper pushed it wide or over, not back into play.", "bold", None),
        ("4", "Keeper's earning his money today.", "After his second or third big save. Either keeper.", "safe", "clean-sheet"),
    ]),
    ("subs", "moments", "They're making a substitution", [
        ("1", "Bit early for that?", "A change before the hour when nobody is injured.", "bold", "substitution"),
        ("2", "Fresh legs. Makes sense.", "Any change after seventy minutes.", "safe", None),
        ("3", "He's been hooked. Not his day.", "When the player coming off has had a poor game.", "bold", "hooked"),
        ("4", "Who's this coming on?", "When a player you don't know is about to come on.", "safe", "the-bench"),
    ]),
    ("injury", "moments", "A player is down injured", [
        ("1", "That doesn't look good.", "When the player stays down and the physio runs on.", "safe", None),
        ("2", "Hamstring. You can tell by the grab.", "When a player pulls up and grabs the back of his thigh.", "bold", None),
        ("3", "Give him the magic sponge.", "When it looks minor and the physio jogs on.", "safe", "magic-sponge"),
        ("4", "Milking it a bit.", "Once he's rolled around and then jogged off. Not before.", "bold", "dive"),
    ]),
    ("near-miss", "moments", "So close", [
        ("1", "Off the woodwork! So close.", "When it hits the post or the bar.", "safe", "hit-the-woodwork"),
        ("2", "Row Z. He's ballooned that.", "A shot that flies miles over.", "bold", "row-z"),
        ("3", "That's a sitter.", "An easy chance, missed.", "bold", "sitter"),
        ("4", "Unlucky. Keep going.", "After any miss by his team.", "safe", "unlucky"),
    ]),
    ("scuffle", "moments", "A nasty tackle or a scuffle", [
        ("1", "Handbags. Nothing in it.", "Pushing and shoving, but nobody swinging.", "bold", "handbags"),
        ("2", "That's a booking all day long.", "After a late or cynical tackle.", "bold", "in-the-book"),
        ("3", "He's gone in two-footed.", "When a player goes into a tackle with both feet off the ground.", "bold", "red-card"),
        ("4", "Ref's going to have a word.", "When the referee calls a player over.", "safe", None),
    ]),
    ("cup-night", "moments", "It's a cup night", [
        ("1", "It's only the League Cup.", "An early League Cup round with half the team rested.", "safe", "league-cup"),
        ("2", "Any giant-killings on tonight?", "A cup night with small clubs playing big ones.", "safe", "giant-killing"),
        ("3", "Cup run! Who've we got next?", "After a cup win, before the next round is drawn.", "safe", "the-cups"),
        ("4", "Win this and it's a trip to Wembley.", "Before or during a semi-final.", "bold", "wembley"),
        ("5", "Do they actually want this one?", "When the line-up is full of reserves.", "bold", "rotation"),
    ]),
    ("sideways", "how_its_going", "They keep passing it sideways", [
        ("1", "There's no urgency.", "When the ball has gone across the back four three times in a row.", "safe", None),
        ("2", "Someone needs to run at them.", "When the other team sits deep and nobody is dribbling.", "bold", None),
        ("3", "All possession, no end product.", "When they have lots of the ball and no chances.", "bold", "possession"),
        ("4", "They're playing in front of them, not through them.", "When every pass stays in front of the defence and none goes past it.", "bold", None),
    ]),
    ("under-pressure", "how_its_going", "His team can't get out of their half", [
        ("1", "Backs to the wall.", "When the other team has all the ball and a few corners in a row.", "safe", "backs-to-the-wall"),
        ("2", "Just get a foot on it.", "When every clearance comes straight back.", "safe", None),
        ("3", "Hoof it if you have to.", "When passing it out from the back keeps failing.", "bold", "hoof"),
        ("4", "Half-time can't come quick enough.", "From about the fortieth minute when they're hanging on.", "safe", None),
    ]),
    ("cruising", "how_its_going", "They're winning comfortably", [
        ("1", "Job done. Take a couple off.", "Two or more up with twenty minutes left.", "safe", None),
        ("2", "Don't go to sleep now.", "Ahead, with time left for the other team to come back.", "safe", "caught-napping"),
        ("3", "Game management now. Keep the ball.", "When they're ahead late and slowing it down.", "bold", "game-management"),
        ("4", "Get the young lad on.", "When the game is safe and there are kids on the bench.", "bold", None),
    ]),
    ("boring", "how_its_going", "Nothing is happening", [
        ("1", "Both happy with a point here.", "A goalless game late on where nobody is pushing.", "bold", "nil-nil"),
        ("2", "Someone score, please.", "Any dull stretch.", "safe", None),
        ("3", "Game of two halves, hopefully.", "At half-time after a dull first half.", "bold", "game-of-two-halves"),
        ("4", "One goal changes this.", "A tight, goalless game.", "safe", None),
    ]),
    ("late-drama", "how_its_going", "It's the last ten minutes and it's close", [
        ("1", "Squeaky bum time.", "One goal in it, minutes left.", "bold", "squeaky-bum-time"),
        ("2", "How long has he added?", "Just before the added-time board goes up.", "safe", "added-time"),
        ("3", "Keep it in the corner. Kill it.", "When his team is a goal up near the end.", "bold", "see-the-game-out"),
        ("4", "I can't watch this.", "Any tight finish.", "safe", None),
    ]),
    ("ref-bad", "how_its_going", "The referee is having a bad day", [
        ("1", "He's lost control of this.", "When players keep surrounding the referee and the cards are flying.", "safe", None),
        ("2", "That's a foul every day of the week.", "When a tackle near the box goes unpunished.", "bold", "free-kick"),
        ("3", "Book him then. Be consistent.", "When one side gets away with what the other was booked for.", "bold", "yellow-card"),
        ("4", "Nobody came to watch the ref.", "When the referee has become the story.", "safe", None),
    ]),
    ("other-lot-winning-ugly", "how_its_going", "The other team is winning ugly", [
        ("1", "Smash and grab, this.", "When they scored from their one chance and his team had the rest.", "bold", "smash-and-grab"),
        ("2", "They've parked the bus.", "When they have everyone behind the ball.", "safe", "park-the-bus"),
        ("3", "Dark arts. Fair play to them.", "When they're time-wasting and winding people up.", "bold", "dark-arts"),
        ("4", "Ref, get on with it.", "When their keeper takes forty seconds over every goal kick.", "safe", None),
    ]),
    ("half-time", "when_he_asks", "Half-time and he asks what you think", [
        ("1", "What did you make of it?", "When he asks at half-time and you haven't made your mind up.", "safe", None),
        ("2", "Better than I expected, honestly.", "When his team are level or ahead against a decent side.", "safe", None),
        ("3", "Need to be braver in the second half.", "When they've been cautious in the first half.", "bold", None),
        ("4", "They'll be getting the hairdryer.", "When they were poor in the first half.", "safe", "hairdryer"),
    ]),
    ("full-time-win", "when_he_asks", "Full-time, they won", [
        ("1", "Deserved that. Never in doubt.", "After a comfortable win.", "safe", None),
        ("2", "Won ugly, but three points is three points.", "After a scrappy win.", "bold", "points"),
        ("3", "Who's your man of the match?", "Straight after any win.", "safe", "man-of-the-match"),
        ("4", "Where are we in the table now?", "After a league win.", "safe", "the-table"),
    ]),
    ("full-time-loss", "when_he_asks", "Full-time, they lost", [
        ("1", "That one stings.", "Straight after a close defeat.", "safe", None),
        ("2", "Robbed. Absolutely robbed.", "Only if a big decision went against them.", "bold", None),
        ("3", "One of those days. We go again.", "After any defeat.", "safe", "we-go-again"),
        ("4", "The performance wasn't there.", "When they were bad, not unlucky.", "bold", None),
    ]),
    ("full-time-draw", "when_he_asks", "Full-time, it was a draw", [
        ("1", "Two points dropped.", "When they were the better team or were winning late on.", "bold", "points"),
        ("2", "Take the point and move on.", "When they were hanging on at the end.", "safe", None),
        ("3", "Nobody's happy with that, are they?", "After a flat nil-nil.", "safe", "nil-nil"),
    ]),
    ("who-was-good", "when_he_asks", "He asks who you thought played well", [
        ("1", "The keeper. Kept them in it.", "When the score was close and the keeper made a few saves.", "safe", None),
        ("3", "Honestly, the full-backs. Up and down all day.", "When the wide defenders were up and down the line all game.", "bold", "full-back"),
        ("5", "Both centre-backs. Won everything in the air.", "When the two central defenders won most of the headers.", "bold", "centre-back"),
    ]),
    ("manager-question", "when_he_asks", "He asks what you think of the manager", [
        ("1", "He needs a run of games to judge him properly.", "When the manager is new.", "safe", "new-manager-bounce"),
        ("2", "The players seem to be playing for him.", "When they look like they're working hard.", "bold", None),
        ("3", "His subs are always a bit late, aren't they?", "When the subs came late again.", "bold", "substitution"),
        ("4", "Do you actually rate him or do you just want him gone?", "When he's been complaining about the manager.", "bold", "sack-race"),
    ]),
    ("big-game-tomorrow", "when_he_asks", "He mentions a big game coming up", [
        ("1", "Who's out injured for it?", "The day before any big game.", "safe", None),
        ("2", "A draw would be fine, wouldn't it?", "When it's away against a bigger team.", "bold", None),
        ("3", "What time is it on? I'll watch the start with you.", "When you'd like to watch it with him.", "safe", "kick-off"),
        ("4", "Proper six-pointer, this.", "Only when both teams are chasing the same thing: the title, top four, survival.", "bold", "six-pointer"),
    ]),
]

# Lines taken out of the bank that an installed build may still hold as a saved
# line (bug hunt U-C1). Builds 2.2-2.4 find a saved line by its id in the current
# content, so the line stays in its situation, with its text unchanged, and is
# listed in retiredIds. Appended after the live lines. Never delete one.
RETIRED = {
    # 2026-11-01: replaced by the centre-back pick (scripted agreement); back 2026-11-04.
    "who-was-good": [
        ("2", "Whoever was running the midfield.", "When one midfielder had the ball all game.", "bold", "box-to-box"),
        ("4", "You tell me. You watched it properly.", "When you honestly could not pick anyone out.", "safe", None),
    ],
}
