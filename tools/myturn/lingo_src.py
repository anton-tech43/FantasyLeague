# Lingo source. (id, category, term, meaning, heard, sayIt, seeAlso)
# meaning ≤170: plain English, with an example where the idea needs one.
# heard ≤90: where the word turns up.  sayIt ≤100: a sentence she can say using it.
# Order matters within a category: nothing relies on a term she has not reached yet.

RULES = [
    ("premier-league", "Premier League", "England's top division. Twenty clubs, each plays the other nineteen twice, August to May.", "Constantly. It is the whole thing.", "\"Is that a Premier League game or one of the cups?\"", []),
    ("points", "Points", "Three for a win, one for a draw, none for a loss. Add them up and that is the table.", "\"Three points is three points\" after any ugly win.", "\"Ugly, but it's three points.\"", ["the-table"]),
    ("the-table", "The table", "The league standings, top to bottom. Top wins the title, the bottom three go down.", "\"Where are we in the table?\" He knows. He wants to say it.", "\"Where does that leave them in the table?\"", ["relegation", "goal-difference"]),
    ("goal-difference", "Goal difference", "Goals scored minus goals let in. Two teams level on points are split by it. A 3-0 win is worth more than a 1-0 win for this reason.", "Late in the season when two teams are neck and neck.", "\"Level on points, so it'll come down to goal difference.\"", ["the-table"]),
    ("relegation", "Relegation", "The bottom three at the end of the season drop down a division, to the Championship. Losing money, players and pride in one go.", "\"Relegation battle\" from about February onwards.", "\"They're in a relegation battle, aren't they?\"", ["championship", "promotion"]),
    ("promotion", "Promotion", "Going up a division. Three clubs come up from the Championship each summer to replace the three that went down.", "In May, usually with someone crying on a pitch.", "\"Who came up this year?\"", ["championship", "play-offs"]),
    ("championship", "The Championship", "The second division, one below the Premier League. Confusing name: winning it does not make you champions of anything much.", "\"They'll be in the Championship next year\" said unkindly.", "\"Is that a Championship side? So they came up recently.\"", []),
    ("play-offs", "Play-offs", "In the Championship the top two go up automatically. The next four play a mini knockout for the third place. One final, one winner, one very rich club.", "Late May. The final is called the richest game in football.", "\"Did they go up automatically or through the play-offs?\"", ["promotion"]),
    ("offside", "Offside", "When the ball is passed to you, you can't already be nearer the goal than the last defender. If you are, the flag goes up and the goal doesn't count.", "Every time a flag goes up and someone on the sofa groans.", "\"Was he offside? He looked level to me.\"", ["var"]),
    ("var", "VAR", "Video Assistant Referee. Someone in a room checks goals, penalties and red cards on replay and tells the referee if he got it badly wrong.", "\"VAR is checking\" followed by two minutes of silence.", "\"Hang on, VAR's checking it. Don't celebrate yet.\"", ["clear-and-obvious"]),
    ("clear-and-obvious", "Clear and obvious", "VAR is only meant to overturn a decision that was obviously wrong, not one that is debatable. The longer the check, the less obvious it was.", "\"If it takes that long it isn't clear and obvious.\"", "\"If it takes this long it's not clear and obvious, is it?\"", ["var"]),
    ("foul", "Foul", "Kicking, tripping, pushing or holding another player. The referee blows, the other team gets a free kick, and if it was bad enough a card follows.", "\"That's a foul!\", shouted most often by the side that has just lost the ball.", "\"That's a foul, surely. He went straight through him.\"", ["free-kick", "yellow-card"]),
    ("handball", "Handball", "Touching the ball with your hand or arm on purpose, or with an arm stuck out making you bigger. Goalkeepers can use their hands, but only inside their own box.", "\"That's handball all day\" about a ball that brushed a shoulder.", "\"His arm was out. That's handball.\"", ["the-box"]),
    ("penalty", "Penalty", "A free shot from twelve yards with only the goalkeeper to beat. Given for a foul or handball inside the box. Scored about three times in four.", "A gasp, then nobody speaks until it's taken.", "\"Penalty! Who takes them for us?\"", ["the-box"]),
    ("the-box", "The box", "The big rectangle in front of each goal, eighteen yards deep. A foul in there is a penalty. Also called the penalty area.", "\"Get it in the box!\" whenever a cross is coming.", "\"Get it in the box, someone!\"", ["penalty"]),
    ("free-kick", "Free kick", "A restart after a foul: the ball is put down and kicked from where the foul happened. Near the goal, it is a chance to score.", "\"That's a free kick every day of the week.\"", "\"That's a free kick all day long.\"", []),
    ("corner", "Corner", "If a defender puts the ball out behind his own goal, the attackers get to cross it in from the corner of the pitch. Tall players love them.", "\"Corners are as good as a goal\" said hopefully.", "\"Corner. Get everyone in the box.\"", []),
    ("throw-in", "Throw-in", "Ball goes out over the sideline, the other team throws it back in, two hands, from behind the head.", "Rarely. Unless someone has a famously long one.", "\"Long throw. They'll launch it into the box.\"", []),
    ("yellow-card", "Yellow card", "A warning from the referee. Two in one game and you are sent off.", "\"He's on a yellow\" means the player has to be careful now.", "\"He's on a yellow, he needs to calm down.\"", ["red-card"]),
    ("red-card", "Red card", "Sent off. The player leaves and the team plays the rest of the game one short. A straight red is for one bad act; two yellows also make a red.", "\"Straight red\" means one bad tackle, no warning first.", "\"That's a red. He's off.\"", ["yellow-card", "ten-men"]),
    ("ten-men", "Ten men", "Playing with one fewer after a red card. Teams usually drop back and defend for their lives.", "\"Down to ten men\" said either with dread or delight.", "\"Down to ten men. Just hang on now.\"", ["red-card"]),
    ("added-time", "Added time", "Minutes added at the end of each half to make up for stoppages: injuries, substitutions, celebrations. Shown on a board by the pitch.", "\"How long has he added?\" the second the board goes up.", "\"How long's he added? Six? Six minutes!\"", []),
    ("extra-time", "Extra time", "Two extra fifteen-minute halves when a cup game is level. Not the same as added time. League games never have it; they just end as a draw.", "In knockout games only.", "\"It's going to extra time. Put the kettle on.\"", ["added-time", "penalty-shootout"]),
    ("penalty-shootout", "Penalty shootout", "If extra time is still level: five penalties each, then one at a time until somebody misses. Pure nerves.", "England fans go quiet at the mention of it.", "\"Penalties. I can't watch penalties.\"", ["extra-time", "the-cups"]),
    ("two-legs", "Two legs", "A cup round played as two matches, one at each ground. First leg, second leg. Neither result decides anything on its own; the two added together do.", "\"The second leg is at home\" is good news.", "\"Is this the first leg or the second?\"", ["aggregate"]),
    ("aggregate", "Aggregate", "Over two legs, add the two scores together. Win the first 2-0, lose the second 1-0, and you go through 2-1 on aggregate. The total is what counts.", "European nights. \"They're 3-2 up on aggregate.\"", "\"So what's the aggregate? Who's actually ahead?\"", ["two-legs", "extra-time"]),
    ("substitution", "Substitution", "Swapping a player on the pitch for one from the bench. Five changes allowed per game since 2022; it used to be three.", "\"Bit early for a sub\" or \"About time.\"", "\"Bit early for a sub, isn't it?\"", ["the-bench"]),
    ("the-bench", "The bench", "The substitutes, sitting beside the pitch waiting to come on. A strong bench means good players in reserve.", "\"He's on the bench\" means not starting, but might play.", "\"He's only on the bench today? Is he injured?\"", ["substitution"]),
    ("starting-eleven", "Starting eleven", "The eleven players who begin the match. Announced about an hour before kick-off, when phones come out.", "\"Team's out\" when the line-up appears on his phone.", "\"Team's out. Who's starting?\"", []),
    ("clean-sheet", "Clean sheet", "Letting in no goals in a match. The goalkeeper's favourite statistic, and a defender's.", "\"Another clean sheet\" said with real pride.", "\"Another clean sheet. The defence has been solid.\"", []),
    ("own-goal", "Own goal", "Putting the ball into your own net. It counts for the other team, and it follows the player around for years.", "A pained \"oh no\" from the whole room.", "\"Oh no. Own goal. Poor lad.\"", []),
    ("brace", "Brace", "Two goals by the same player in one match. Three is a hat-trick. There is no special word for four.", "\"He got a brace\" in the match report.", "\"That's his brace. One more for a hat-trick.\"", ["hat-trick"]),
    ("hat-trick", "Hat-trick", "Three goals by one player in one match. Two is a brace. The player traditionally keeps the match ball.", "For days afterwards.", "\"Hat-trick! He's taking the ball home.\"", ["brace"]),
    ("assist", "Assist", "The pass that leads directly to a goal. The scorer gets the headline, the assist gets the credit from people who know.", "\"Goals and assists\" when he's rating a player.", "\"Lovely assist. The pass was the best bit.\"", []),
    ("fixtures", "Fixtures", "The list of upcoming matches: who plays who, when, and where. Published in June for the whole season.", "\"Have you seen the fixtures?\" in June, when they come out.", "\"What's the next fixture? Home or away?\"", []),
    ("derby", "Derby", "A match between two local rivals, usually from the same city. Pronounced darby. The week is tense before, during and after.", "The week before, the week of, and the week after.", "\"It's the derby this weekend, isn't it? Are you nervous?\"", []),
    ("the-cups", "The cups", "Knockout competitions run alongside the league: the FA Cup and the League Cup. Lose once and you are out of it for the season.", "\"It's only the cup\" when they lose, \"a cup run\" when they win.", "\"Is this the league or the cup?\"", ["fa-cup", "league-cup", "wembley", "extra-time"]),
    ("fa-cup", "FA Cup", "The oldest cup competition in the world, since 1871. Every club in England can enter, so tiny teams sometimes get to play giants. Final at Wembley in May.", "\"The magic of the cup\" when a small club wins.", "\"FA Cup weekend. Any giant-killings on?\"", ["the-cups", "wembley"]),
    ("league-cup", "League Cup", "The League Cup (Carabao Cup) is the smaller of the two domestic cups, so it takes the name of whichever sponsor is paying. Semi-finals over two legs, final at Wembley.", "\"Good chance to rest people\" from the manager.", "\"It's only the League Cup. He'll rest half the team.\"", ["the-cups", "wembley", "two-legs"]),
    ("champions-league", "Champions League", "Europe's top club competition. The best clubs from each country, midweek nights, that anthem before kick-off.", "Tuesday and Wednesday nights, September to May.", "\"Champions League night. What time's kick-off?\"", ["europa-league", "conference-league", "two-legs"]),
    ("europa-league", "Europa League", "Europe's second competition, for clubs that finished just below the Champions League places. Thursday nights.", "\"Thursday night football\" said with a slight sigh.", "\"Thursday night football. Is that the Europa League?\"", ["champions-league", "conference-league"]),
    ("conference-league", "Conference League", "Europe's third competition, below the Champions League and the Europa League. Thursday nights, smaller clubs, and a real trophy for whoever wins it.", "Thursday nights, often alongside the Europa League.", "\"Is that the Europa League or the Conference League?\"", ["europa-league", "champions-league"]),
    ("transfer-window", "Transfer window", "The only times clubs can buy and sell players: the summer, and the month of January. Outside those, nothing moves.", "\"Deadline day\" on the last day, with a countdown clock.", "\"Window shuts Monday. Are they buying anyone?\"", ["deadline-day"]),
    ("deadline-day", "Deadline day", "The last day of the transfer window. Deals get done at midnight and reporters stand outside stadiums in the cold.", "Someone shouting \"here we go\" at a phone.", "\"Deadline day. Anything happening?\"", ["transfer-window", "here-we-go"]),
    ("loan", "Loan", "Borrowing a player from another club for a season, or lending one out. Common for young players who need games.", "\"He's out on loan\" about a promising kid.", "\"Is he ours or on loan?\"", []),
    ("sacked", "Sacked", "Fired. Managers get the sack when results go bad; players never do, they get sold or loaned out.", "\"He'll be sacked by Christmas\" after three defeats.", "\"If they lose this, is he getting sacked?\"", ["sack-race"]),
]

TACTICS = [
    ("formation", "Formation", "How the ten outfield players line up, read from the back. 4-3-3 means four defenders, three midfielders, three attackers. The goalkeeper is never counted.", "\"They've gone 4-4-2\" as if it explains everything.", "\"What formation are they playing? Looks like a back three.\"", ["back-four"]),
    ("back-four", "Back four", "The four defenders in a line in front of the goalkeeper: two centre-backs in the middle, a full-back on each side.", "\"The back four were solid\" is high praise.", "\"The back four have been solid today.\"", ["full-back", "centre-back"]),
    ("centre-back", "Centre-back", "The two big defenders in the middle. Heading, tackling, shouting at everyone else.", "\"He's a proper centre-back\" means old-fashioned and tough.", "\"He's a proper centre-back. Wins every header.\"", []),
    ("full-back", "Full-back", "The defenders on the left and right who also sprint forward to attack. Busiest job on the pitch.", "\"The full-backs were up and down all day.\"", "\"The full-backs have been up and down all game.\"", []),
    ("wing-back", "Wing-back", "A full-back who plays higher up the pitch, almost as a winger, because there are three centre-backs behind him.", "When a team plays with a back three.", "\"They're playing wing-backs today, so it's a back three.\"", ["full-back", "back-four"]),
    ("holding-midfielder", "Holding midfielder", "The midfielder who stays back and protects the defence instead of running forward. Unglamorous, essential.", "\"The six\" or \"the number six\", after the shirt number they used to wear.", "\"Who's playing the holding role? He's not getting forward.\"", ["box-to-box"]),
    ("box-to-box", "Box-to-box", "A midfielder who runs from his own penalty area to the other one all game. Defends, attacks, never stops.", "\"Proper box-to-box midfielder\" said admiringly.", "\"He's a proper box-to-box player. Everywhere.\"", ["holding-midfielder"]),
    ("number-ten", "Number ten", "The creative player just behind the striker who makes the clever passes. Named after the shirt number the best of them wore.", "\"He's a classic ten\" about someone who can't be bothered to defend.", "\"He's playing as the ten today, just behind the striker.\"", ["playmaker"]),
    ("playmaker", "Playmaker", "The player everything goes through. Sees passes nobody else sees. Stop him and you stop the team.", "\"He makes them tick\" is the phrase.", "\"He's the one who makes them tick.\"", ["number-ten"]),
    ("winger", "Winger", "An attacker who plays out wide near the touchline, runs at defenders and crosses the ball in.", "\"Get it wide to the winger!\"", "\"Get it out wide! The winger's in space.\"", []),
    ("striker", "Striker", "The player whose whole job is scoring goals. Also called a forward, a centre-forward or a number nine.", "\"They need a striker\" about half the clubs in the league.", "\"They need a proper striker, don't they?\"", ["false-nine", "target-man"]),
    ("target-man", "Target man", "A big striker the team aims long balls at. He holds the ball up and brings others into play.", "\"Get it up to the big man\" when a team is desperate.", "\"Just get it up to the big man.\"", ["striker", "long-ball"]),
    ("false-nine", "False nine", "A striker who drops back into midfield instead of staying up front, so the defenders don't know who to mark.", "In clever tactical chats. Sounds fancier than it is.", "\"He's playing as a false nine, dropping into midfield.\"", ["striker"]),
    ("pressing", "Pressing", "Chasing the opponent the moment he gets the ball, all over the pitch, to force a mistake. Exhausting when it works and when it doesn't.", "\"They press really well\" about energetic teams.", "\"They press so well. Nobody gets a second on the ball.\"", ["high-press", "low-block"]),
    ("high-press", "High press", "Pressing right up near the other team's goal, so they can't even pass the ball out from their own defence.", "When a team wins the ball near the corner flag and scores.", "\"The high press won them that. Forced the mistake.\"", ["pressing"]),
    ("low-block", "Low block", "The whole team sitting deep near their own goal, letting the other side have the ball and hoping to hit them on the counter.", "\"They've sat in a low block\" about a team defending a lead.", "\"They're sitting in a low block. Someone needs to unlock it.\"", ["park-the-bus", "counter-attack"]),
    ("park-the-bus", "Park the bus", "Defending with everyone and attacking with nobody, as if a bus were parked across the goal. Usually to protect a lead.", "Usually as an insult about a boring opponent.", "\"They've parked the bus. This'll be hard work.\"", ["low-block"]),
    ("counter-attack", "Counter-attack", "Winning the ball and racing up the pitch fast before the other team can get back into position.", "\"Dangerous on the counter\" about quick teams.", "\"They're dangerous on the counter. Don't push too many forward.\"", ["on-the-break"]),
    ("possession", "Possession", "How much of the game a team has the ball, shown as a percentage. Having it is nice; scoring is better.", "\"Sixty percent possession and nothing to show for it.\"", "\"All that possession and nothing to show for it.\"", ["tiki-taka"]),
    ("tiki-taka", "Tiki-taka", "Lots of short, quick passes to keep the ball and wear the other team out. Barcelona and Spain made it famous.", "Half in praise, half in mockery.", "\"Bit of tiki-taka there. Nobody can get near them.\"", ["possession"]),
    ("long-ball", "Long ball", "Kicking the ball high and far up the pitch instead of passing it along the ground. Simple, direct, unloved.", "\"Route one\" is the same idea, said more rudely.", "\"Long ball again. Not pretty, but it works.\"", ["target-man", "route-one", "hoof"]),
    ("man-marking", "Man marking", "A defender following one particular attacker everywhere he goes, rather than guarding an area.", "\"Who's marking him?\" after a free header.", "\"Who was marking him? He was completely free.\"", []),
    ("zonal-marking", "Zonal marking", "At corners and free kicks, each defender guards a patch of ground instead of a person. Blamed for every goal from a corner.", "Blamed for every goal from a corner.", "\"Zonal marking. Nobody's actually on anyone.\"", ["man-marking"]),
    ("set-piece", "Set piece", "Any restart from a dead ball: corners, free kicks, throw-ins. Teams rehearse them in training all week.", "\"Strong from set pieces\" about tall teams.", "\"They're strong from set pieces. Watch the corners.\"", ["corner", "free-kick"]),
    ("overlap", "Overlap", "A full-back running past the winger on the outside to give him someone to pass to.", "\"Great overlap\" from a co-commentator.", "\"Lovely overlap from the full-back there.\"", ["full-back"]),
    ("through-ball", "Through ball", "A pass slid between the defenders for a teammate to run onto. When it works it looks like magic.", "\"What a ball\" when it works.", "\"What a ball! Straight through them.\"", []),
    ("cutback", "Cutback", "Getting to the byline and passing the ball back across the goal for someone to tap in. Modern teams score half their goals this way.", "Modern teams score half their goals this way.", "\"Cut it back! Don't shoot from there.\"", []),
    ("inverted-full-back", "Inverted full-back", "A full-back who steps into midfield when his team has the ball, to give them an extra passer in the middle.", "Guardiola fans. Sounds very clever.", "\"The full-back's inverting. He's basically a midfielder now.\"", ["full-back"]),
    ("half-space", "Half-space", "The gap between the middle of the pitch and the wing, where clever attackers like to get the ball because nobody is quite sure who marks them.", "Tactics podcasts. Nod if you hear it.", "\"He keeps finding space in the half-space. Nobody picks him up.\"", []),
    ("xg", "xG", "Expected goals. A number for how good a chance was: a tap-in is nearly 1, a shot from forty yards is nearly 0. Add them up to see who deserved to win.", "\"The xG was 2.5 and we lost 1-0\" as a complaint.", "\"What was the xG? Felt like they should've scored three.\"", []),
    ("game-management", "Game management", "Slowing the match down when you are winning: keeping the ball, taking your time, no risks. Called clever by the winners and cynical by the losers.", "\"Good game management\" or \"cynical\", depending on who's winning.", "\"Good game management. Just keep the ball now.\"", ["see-the-game-out"]),
    ("dark-arts", "The dark arts", "The sneaky side of winning: time-wasting, little fouls, winding opponents up. Fans hate it from the other team and defend it from their own.", "\"Bit of the dark arts\" said with grudging respect.", "\"Bit of the dark arts there. Fair play, it's working.\"", ["game-management"]),
    ("rotation", "Rotation", "Changing several players between matches to keep legs fresh. In an early League Cup round a manager might make eight changes and hand the young lads a game.", "\"He's rotating\" when the line-up looks unfamiliar.", "\"He's rotated half the side. It's only the League Cup.\"", ["league-cup", "starting-eleven", "the-bench"]),
]

MATCH_SITUATIONS = [
    ("kick-off", "Kick-off", "The start of the match, and the restart after half-time or a goal.", "\"What time's kick-off?\" about eight times a weekend.", "\"What time's kick-off? I'll come and watch the start.\"", []),
    ("half-time", "Half-time", "The fifteen-minute break in the middle. Kettle time, and the manager's chance to shout.", "\"Half-time team talk\" when the manager needs to fix things.", "\"Half-time. What did you make of that?\"", []),
    ("full-time", "Full-time", "The end of the match. The referee blows and it is over, whatever the score.", "\"FT\" in a text. Then either celebration or silence.", "\"Full-time. Right, where does that leave us?\"", []),
    ("nil-nil", "Nil-nil", "No goals for either side. Football says nil, not zero. A dull one is a bore draw.", "\"Bore draw\" if it was dull, \"a tight game\" if he's being kind.", "\"Nil-nil. Bit of a bore draw, that.\"", []),
    ("see-the-game-out", "See the game out", "Hold onto a lead until the final whistle without anything going wrong. The hardest ten minutes in football.", "\"Just see it out\" in the last ten minutes.", "\"Just see the game out now. Nothing silly.\"", ["game-management", "squeaky-bum-time"]),
    ("squeaky-bum-time", "Squeaky bum time", "The nervous final minutes when your team is only just ahead and the other lot are pushing. Fans shift about in plastic seats, hence the squeak. Alex Ferguson's phrase.", "The last ten minutes of anything close.", "\"Right, squeaky bum time. I can't watch.\"", ["see-the-game-out", "added-time"]),
    ("six-pointer", "Six-pointer", "A match between two teams chasing the same thing. Win it and you gain three points and stop your rival getting three: six points swing.", "Relegation battles in spring, title races in April.", "\"This is a proper six-pointer, isn't it?\"", ["relegation-battle", "title-race"]),
    ("top-four", "Top four", "Finishing in the first four places, which earns a Champions League spot for next season. The realistic target for clubs who won't win the title.", "\"Top four is the aim\" from big clubs that won't win the title.", "\"Top four is the aim this year, surely?\"", ["champions-league"]),
    ("title-race", "Title race", "Two or more teams close at the top with a few games left. Every result matters, every weekend.", "\"It's a proper title race\" once March arrives.", "\"It's a proper title race now. Who do you think cracks first?\"", ["bottle-it"]),
    ("relegation-battle", "Relegation battle", "Several clubs near the bottom fighting to stay out of the three places that go down. Miserable and gripping.", "In spring, with a lot of stress.", "\"They're in a relegation battle. Every point counts now.\"", ["relegation", "six-pointer"]),
    ("sitter", "Sitter", "An easy chance that should have been a goal and wasn't. The kind you would score yourself, you tell him.", "\"How has he missed that?\"", "\"That's a sitter. How has he missed that?\"", []),
    ("clinical-finish", "Clinical finish", "A cool, precise shot that goes exactly where it should. Nothing spectacular, nothing wasted. The scorer is a clinical finisher.", "Commentators, about a striker who never seems to miss.", "\"Clinical. Absolutely clinical finish.\"", ["sitter"]),
    ("screamer", "Screamer", "A spectacular goal, usually hit very hard from a long way out. Followed by a replay, then another.", "\"What a screamer\" and then the replay, twice.", "\"What a screamer! Show me that again.\"", ["top-bins", "worldie"]),
    ("top-bins", "Top bins", "The top corner of the goal. The hardest place for a keeper to reach and the nicest place to score.", "\"Top bins!\" with real joy.", "\"Top bins! Keeper had no chance.\"", ["screamer"]),
    ("worldie", "Worldie", "A world-class goal. Short for world-class. Save it for the truly special ones or it loses its power.", "Only for the very best ones.", "\"That's a worldie. Goal of the season, that.\"", ["screamer"]),
    ("hit-the-woodwork", "Hit the woodwork", "The ball strikes the post or the crossbar and stays out. Close enough to hurt.", "\"Off the woodwork\" with a groan from the whole room.", "\"Off the woodwork! So close.\"", ["sitter"]),
    ("row-z", "Row Z", "The back row of the stand. Where a shot goes when it is blazed miles over, or where a defender deliberately hoofs the ball to safety.", "\"That's in Row Z\" about a shot that nearly hit the roof.", "\"Row Z. He's ballooned that.\"", ["hoof"]),
    ("howler", "Howler", "A terrible, obvious mistake, usually by a goalkeeper or defender: a ball through the hands, a pass straight to the opposition. Everyone saw it.", "\"Absolute howler\" about a ball rolling under someone's foot.", "\"That's a howler from the keeper. He'll not sleep tonight.\"", ["own-goal"]),
    ("hospital-ball", "Hospital ball", "A careless pass that lands between two players from opposite sides, so both go for it and somebody gets hurt.", "\"That's a hospital ball\" when a pass leaves a teammate exposed.", "\"Hospital ball, that. He's left him in trouble.\"", []),
    ("hoof", "Hoof it", "Kick the ball as hard and far as you can with no real aim, usually to get it away from danger. Not elegant. Sometimes exactly right.", "\"Just hoof it!\" from the sofa when the defence is under pressure.", "\"Just hoof it! Get it out of there.\"", ["long-ball", "row-z"]),
    ("dive", "Dive", "Falling over on purpose to trick the referee into giving a foul or a penalty. Cheating, technically. Very common, technically.", "\"He dived!\" whenever an opponent goes down.", "\"He's dived. Nobody touched him.\"", []),
    ("early-bath", "Early bath", "Being sent off. The player heads to the showers while everyone else is still playing.", "\"He's off for an early bath\" after a red card.", "\"Early bath for him. That was a proper tackle.\"", ["red-card"]),
    ("handbags", "Handbags", "A pushing and shoving scuffle between players that looks angry but never becomes a proper fight. Nobody gets hurt.", "\"Handbags\" when two players square up and do nothing.", "\"Handbags. Nothing in that.\"", []),
    ("in-the-book", "In the book", "Booked. The referee writes the player's name in his notebook when he gives a yellow card.", "\"He's in the book\" after a yellow card.", "\"He's in the book now. He'll have to be careful.\"", ["yellow-card"]),
    ("hooked", "Hooked", "Substituted, usually because you were playing badly. Taken off, not rested.", "\"He's been hooked\" about a player having a bad day.", "\"He's been hooked. Not his day.\"", ["substitution"]),
    ("nutmeg", "Nutmeg", "Poking the ball between a defender's legs and running round him to collect it. Humiliating for the defender, hilarious for everyone else.", "A cheer that has nothing to do with a goal.", "\"Nutmeg! He'll never live that down.\"", ["done-him"]),
    ("done-him", "Done him", "Got past a defender so completely he was left standing. Skinned him and left him for dead mean the same.", "\"He's done him\" after a dribble.", "\"He's done him there. Left him for dead.\"", ["nutmeg"]),
    ("caught-napping", "Caught napping", "A defender switching off for a second and letting an attacker get free. Also called going to sleep.", "\"Caught napping\" or \"gone to sleep\" after a goal against.", "\"They were caught napping there. Nobody was awake.\"", []),
    ("against-the-run-of-play", "Against the run of play", "A goal for the team that has been playing worse. They were being battered, then scored anyway.", "Commentators, when the wrong team scores.", "\"That's against the run of play. They've been terrible.\"", ["smash-and-grab"]),
    ("smash-and-grab", "Smash and grab", "Winning a game you were outplayed in, with one late goal. A burglary, football-style.", "Said by whichever side lost.", "\"Smash and grab, that. They didn't deserve it.\"", ["against-the-run-of-play"]),
    ("game-of-two-halves", "A game of two halves", "The oldest cliché in football: a match that changed completely after half-time. Said half-jokingly, always.", "Pundits, with a straight face.", "\"Game of two halves, this. Completely different after the break.\"", ["half-time"]),
    ("backs-to-the-wall", "Backs to the wall", "Defending desperately with everyone behind the ball because the other team has all the pressure.", "\"Backs to the wall\" in the last twenty minutes of a close game.", "\"Backs to the wall now. Just hang on.\"", ["low-block"]),
    ("in-the-mixer", "In the mixer", "Launching the ball into the crowded penalty box and hoping. Late-game desperation, and sometimes it works.", "\"Just get it in the mixer\" in the last minute.", "\"Get it in the mixer! Anything now.\"", ["the-box"]),
    ("route-one", "Route one", "The simplest way to attack: kick it long and chase it. Named after the most direct road.", "As an insult about direct teams.", "\"Route one. Not pretty, is it?\"", ["long-ball"]),
    ("on-the-break", "On the break", "Attacking fast right after winning the ball, the same as a counter-attack.", "\"They caught them on the break.\"", "\"They got caught on the break there.\"", ["counter-attack"]),
    ("dead-rubber", "Dead rubber", "A match that no longer matters because everything has already been decided. Nobody tries very hard.", "Last group game of a tournament, or the final league game.", "\"It's a dead rubber. Nothing riding on it.\"", []),
    ("giant-killing", "Giant-killing", "A small club knocking a big one out of a cup. The FA Cup's whole reputation rests on it.", "FA Cup weekends in January and February.", "\"Any giant-killings this weekend?\"", ["fa-cup", "the-third-round", "the-magic-of-the-cup"]),
    ("hairdryer", "The hairdryer", "A manager screaming at players at half-time from so close their hair moves. Named for Alex Ferguson, who was famous for it.", "\"They'll be getting the hairdryer\" after a bad first half.", "\"They'll be getting the hairdryer at half-time.\"", ["half-time"]),
    ("man-of-the-match", "Man of the match", "The best player on the day, picked by the broadcaster or a sponsor. A safe question to ask any fan.", "\"Who's your man of the match?\" is a safe question every time.", "\"Who's your man of the match?\"", []),
    ("top-drawer", "Top drawer", "Excellent. A top-drawer pass, a top-drawer save. Pundit English for very, very good.", "Pundits, about anything they liked.", "\"Top drawer, that. Absolute quality.\"", ["worldie"]),
    ("second-ball", "Second ball", "After a header or a clearance, the loose ball that drops. Winning the second ball means reacting quickest to it.", "\"They won the second ball\" as praise for hard work.", "\"They keep winning the second ball. That's why they're on top.\"", []),
    ("unlucky", "Unlucky", "What fans shout at a player who has just missed. Means nothing and everything.", "Shouted at a player who has just missed.", "\"Unlucky! Keep going.\"", ["sitter"]),
]

CULTURE = [
    ("fergie-time", "Fergie time", "Generous added time that seems to appear whenever a big club needs a goal. Named for Alex Ferguson's Manchester United, who scored a lot of late winners.", "Sarcastically, by fans of every other club.", "\"Fergie time. Of course they've added six minutes.\"", ["added-time"]),
    ("the-gaffer", "The gaffer", "The manager. Old British slang for the boss, still used by players and fans.", "\"The gaffer's got them playing\" from players and pundits alike.", "\"What's the gaffer like? Do the players rate him?\"", ["the-boss"]),
    ("the-boss", "The boss", "Also the manager. Players say it so they don't have to use his name in interviews.", "Post-match interviews. \"The boss said to keep going.\"", "\"The boss won't be happy with that.\"", ["the-gaffer"]),
    ("hard-man", "Hard man", "A player famous for tough, physical, slightly frightening football. Tackles first, apologises never.", "\"Proper hard man\" about a centre-back or a midfielder who scares people.", "\"He's a proper hard man. You wouldn't want to cross him.\"", ["centre-back"]),
    ("class-act", "Class act", "A player or manager admired for how they behave as much as how they play. Good on the pitch, better off it.", "About a player who does charity work or handles a loss with grace.", "\"He's a class act, that one. On and off the pitch.\"", []),
    ("top-top-player", "Top, top player", "Pundit-speak for very good. Two tops is better than one, and nobody knows why.", "Match of the Day, any week.", "\"Top, top player. Genuinely.\"", ["top-drawer"]),
    ("match-of-the-day", "Match of the Day", "The BBC's Saturday night highlights show, running since 1964. The theme tune alone makes fans sit up.", "\"Just watching MOTD\" at 10.30pm on a Saturday.", "\"Are we watching Match of the Day tonight?\"", ["goal-of-the-month"]),
    ("pundit", "Pundit", "An ex-player who talks about the match on TV. Paid to have opinions, blamed for having them.", "\"He's a pundit now\" about a player who retired.", "\"What did the pundits say about it?\"", ["match-of-the-day"]),
    ("the-lads", "The lads", "The team. How players and fans refer to their own side.", "\"Proud of the lads\" after a hard game.", "\"The lads did well today.\"", []),
    ("bottle-it", "Bottle it", "To lose your nerve at the crucial moment and throw away something you should have won. The cruellest word in a title race.", "Cruelly, about title races that collapsed.", "\"Do you think they'll bottle it?\"", ["title-race"]),
    ("banter", "Banter", "Teasing between fans. Mostly friendly, occasionally not, always defended as \"just banter\".", "\"It's just banter\" after a text that went slightly too far.", "\"Is that banter or are you actually annoyed?\"", []),
    ("group-chat", "The group chat", "Where his mates react to every goal in real time. Louder than the stadium and less forgiving.", "His phone buzzing eleven times in a row after a goal.", "\"What's the group chat saying?\"", ["banter"]),
    ("season-ticket", "Season ticket", "A pass for every home league game. Waiting lists at big clubs can be years long, and people inherit them.", "\"I've had a season ticket since I was eight.\"", "\"Have you ever had a season ticket?\"", []),
    ("away-day", "Away day", "Travelling to watch the team at another ground. Trains, pubs, singing, and a long journey home if they lose.", "\"Big away day\" when it's somewhere far or somewhere fun.", "\"Is it an away day? Who are you going with?\"", ["the-away-end"]),
    ("the-away-end", "The away end", "The section of the stadium where the travelling fans sit. Usually the loudest part of the ground.", "\"Listen to the away end\" when the home fans have gone quiet.", "\"Listen to the away end. They're louder than the home fans.\"", ["away-day"]),
    ("kop", "The Kop", "Liverpool's famous home stand at Anfield, where the loudest fans sing. Other grounds borrowed the name for their own big stand.", "Anfield nights on TV.", "\"Is that the Kop end? It's so loud.\"", []),
    ("terraces", "The terraces", "The old standing areas at football grounds. Mostly seats now, but the word stuck for the fans and their songs.", "\"Terrace chant\" about a song the crowd sings.", "\"That's a proper terrace chant, that.\"", ["chant"]),
    ("chant", "Chant", "A song sung by the crowd, usually to a pop tune with new words about a player or the manager.", "Him humming one in the kitchen.", "\"What's that chant they're singing? What are the words?\"", ["terraces"]),
    ("half-and-half-scarf", "Half-and-half scarf", "A souvenir scarf with both teams' colours on it. Proper fans find them deeply embarrassing.", "Mocked outside every big game.", "\"Please tell me you've never owned a half-and-half scarf.\"", []),
    ("plastic-fan", "Plastic fan", "Someone accused of supporting a club only because it wins. The insult of choice between fans.", "Thrown at fans of whoever is winning.", "\"Is he a real fan or a plastic?\"", ["glory-hunter"]),
    ("glory-hunter", "Glory hunter", "A fan who picked a team for its trophies rather than any real connection to it.", "\"Typical glory hunter\" about a mate who supports a club far away.", "\"Why does he support them? Bit of a glory hunter?\"", ["plastic-fan"]),
    ("the-boot-room", "The boot room", "Liverpool's old coaching room where the next manager was quietly promoted from within. Now means any club that grows its own.", "History chats about how Liverpool used to run things.", "\"Is that a boot room appointment, promoted from inside?\"", []),
    ("the-invincibles", "The Invincibles", "Arsenal's 2003-04 team, who went the whole league season without losing a game. Arsenal fans mention it roughly twice a year.", "From every Arsenal fan, about twice a year.", "\"Were the Invincibles as good as everyone says?\"", []),
    ("sack-race", "Sack race", "The unofficial contest for which manager gets fired first each season. Bookmakers take bets on it.", "\"He's favourite in the sack race\" after three losses.", "\"Is he favourite in the sack race now?\"", ["sacked", "new-manager-bounce"]),
    ("new-manager-bounce", "New manager bounce", "The short burst of good results a team often gets right after changing manager. It rarely lasts.", "\"Just the bounce\" when a new manager wins his first two.", "\"Is that just the new manager bounce, or is he actually good?\"", ["sack-race"]),
    ("silly-season", "Silly season", "The summer, when there is no football and every transfer rumour gets printed as if it were true.", "\"Ignore it, it's silly season\" about a wild headline.", "\"Is that real or is it just silly season?\"", ["transfer-window"]),
    ("here-we-go", "Here we go", "Transfer reporter Fabrizio Romano's phrase for a deal that is definitely happening. Fans wait for it like a verdict.", "Screenshot in the group chat with several exclamation marks.", "\"Has Romano said here we go yet?\"", ["deadline-day"]),
    ("football-twitter", "Football Twitter", "The online corner where fans argue about everything, all day, forever. Not a place for the calm.", "\"Football Twitter is going mad\" about anything at all.", "\"What's Football Twitter saying? Actually, don't tell me.\"", ["banter"]),
    ("fantasy-football", "Fantasy football", "An online game where you pick real players and score points from their real performances. Explains why he cheers for players he hates.", "\"He's in my fantasy team\" about a player he's suddenly cheering for.", "\"Is that a fantasy football thing, or do you actually like him?\"", []),
    ("we-go-again", "We go again", "What players and fans say after a bad result. Move on, next match. Half slogan, half coping mechanism.", "Player interviews after a defeat, and his text the morning after.", "\"One of those days. We go again.\"", []),
    ("the-lino", "The lino", "The linesman, now officially an assistant referee. The one with the flag who decides offsides.", "\"Lino!\" shouted at a flag that went up or stayed down.", "\"The lino's flagged. Offside.\"", ["offside"]),
    ("wags", "WAGs", "Old tabloid slang for players' wives and girlfriends, from the 2006 World Cup era. Mostly retired now, thankfully.", "In stories about the 2006 World Cup.", "\"Please tell me nobody says WAGs any more.\"", []),
    ("magic-sponge", "The magic sponge", "The old joke about physios curing any injury with a wet sponge. Players hop up as if nothing happened.", "Ironically, when a player recovers very quickly.", "\"Give him the magic sponge, he'll be fine.\"", []),
    ("goal-of-the-month", "Goal of the month", "Match of the Day's pick of the best goal, voted by viewers. Long-range strikes usually win.", "\"That's goal of the month\" about any long-range strike.", "\"That's goal of the month, surely?\"", ["match-of-the-day", "worldie"]),
    ("the-magic-of-the-cup", "The magic of the cup", "The idea that anything can happen in the FA Cup, proved every year by a small club beating a big one.", "Commentators, the moment a non-league side scores.", "\"That's the magic of the cup, isn't it?\"", ["fa-cup", "giant-killing", "the-third-round"]),
    ("wembley", "Wembley", "England's national stadium, in north London. Both domestic cup finals are played there, and the FA Cup semi-finals too. Ninety thousand seats under an arch.", "\"A trip to Wembley\" means the cup run has gone deep.", "\"So a win here is a trip to Wembley?\"", ["the-cups", "fa-cup", "league-cup"]),
    ("the-third-round", "The third round", "The FA Cup round in early January, when the Premier League clubs come in. It is the draw that can send a big club to a tiny ground on a wet Sunday.", "\"Who did we get in the third round?\" after the draw.", "\"Third round draw. Who have we got?\"", ["fa-cup", "giant-killing", "the-magic-of-the-cup"]),
]

TERMS = [("rules", *t) for t in RULES] + [("tactics", *t) for t in TACTICS] + [("match_situations", *t) for t in MATCH_SITUATIONS] + [("culture", *t) for t in CULTURE]

# ---------------------------------------------------------------- levels
#
# 157 words at once is a wall. LEVELS is the order she meets them, twelve
# steps of ten to fourteen. Two rules built the list: a word comes after
# anything its meaning leans on, and slang comes after the plain word it
# plays with ("early bath" after "red card", "the lino" after "offside").
#
# Level 1 is the first evening on the sofa, and nothing else: the competition
# they are watching, the three moments that break the game up (kick-off,
# half-time, full-time), the table he checks, the two decisions that stop
# play and start an argument (offside, penalty), the screen that follows them
# (VAR), and the two cards, because a booking happens in every game she will
# ever watch and a derby does not (2026-09-09 review: clean sheet and derby
# moved to level 2, where "foul" and "ten men" now sit with the cards' cousins).
# Deliberately no cups, no top four, no relegation — those need the table
# first, so they open level 2.
#
# A handful of seeAlso links used to point forward at a word twelve levels
# away (half-time → hairdryer, fa-cup → giant-killing). They were dropped in
# that direction only; every one of them still exists on the later word
# pointing back, which is the direction that helps.
LEVELS = [
    # 1 — The first ten.
    ["premier-league", "kick-off", "half-time", "full-time", "the-table",
     "offside", "penalty", "var", "yellow-card", "red-card"],
    # 2 — The rest of the rules she sees in her first few games.
    ["points", "goal-difference", "relegation", "promotion", "top-four",
     "the-box", "foul", "handball", "free-kick", "corner", "throw-in",
     "ten-men", "clean-sheet", "derby", "clear-and-obvious"],
    # 3 — The other competitions, and what happens when the clock runs out.
    ["championship", "play-offs", "added-time", "extra-time",
     "penalty-shootout", "the-cups", "fa-cup", "league-cup", "wembley",
     "champions-league", "europa-league", "conference-league", "fixtures"],
    # 4 — The match itself: who starts, who comes on, what a goal is called.
    ["starting-eleven", "substitution", "the-bench", "two-legs", "aggregate",
     "own-goal", "assist", "brace", "hat-trick", "man-of-the-match",
     "nil-nil", "set-piece", "formation"],
    # 5 — Who is on the pitch. Positions, from the back forwards.
    ["back-four", "centre-back", "full-back", "wing-back", "holding-midfielder",
     "box-to-box", "number-ten", "playmaker", "winger", "striker",
     "target-man", "false-nine", "rotation"],
    # 6 — How a team plays, in the words the commentator uses.
    ["pressing", "high-press", "low-block", "park-the-bus", "counter-attack",
     "possession", "tiki-taka", "long-ball", "route-one", "man-marking",
     "zonal-marking", "overlap", "through-ball"],
    # 7 — The finer tactical words, and seeing a lead out.
    ["cutback", "inverted-full-back", "half-space", "xg", "game-management",
     "see-the-game-out", "squeaky-bum-time", "dark-arts", "on-the-break",
     "hoof", "row-z", "in-the-mixer", "second-ball"],
    # 8 — What to call a good moment.
    ["sitter", "clinical-finish", "screamer", "top-bins", "worldie",
     "top-drawer", "hit-the-woodwork", "unlucky", "nutmeg", "done-him",
     "caught-napping", "against-the-run-of-play", "smash-and-grab"],
    # 9 — What to call a bad one, and the games that decide a season.
    ["howler", "hospital-ball", "dive", "early-bath", "handbags",
     "in-the-book", "hooked", "backs-to-the-wall", "game-of-two-halves",
     "dead-rubber", "six-pointer", "title-race", "relegation-battle"],
    # 10 — The season around the match: transfers, managers, the telly.
    ["transfer-window", "deadline-day", "loan", "silly-season", "here-we-go",
     "sacked", "sack-race", "new-manager-bounce", "the-gaffer", "the-boss",
     "hairdryer", "bottle-it", "match-of-the-day", "pundit"],
    # 11 — The ground, and the people in it.
    ["season-ticket", "away-day", "the-away-end", "terraces", "chant",
     "kop", "half-and-half-scarf", "the-lads", "banter", "group-chat",
     "goal-of-the-month", "the-lino", "magic-sponge", "we-go-again"],
    # 12 — The in-jokes, the myths and the cup romance.
    ["fergie-time", "giant-killing", "the-third-round", "the-magic-of-the-cup",
     "hard-man", "class-act", "top-top-player", "plastic-fan", "glory-hunter",
     "the-boot-room", "the-invincibles", "football-twitter", "fantasy-football",
     "wags"],
]

LEVEL_OF = {tid: i + 1 for i, ids in enumerate(LEVELS) for tid in ids}

# The runnable check: every term is placed exactly once, and nothing is placed
# that does not exist. validate_content.py checks the rest (10 at level 1,
# no gaps, no seeAlso pointing more than one level ahead).
_ids = [t[1] for t in TERMS]
assert len(LEVEL_OF) == sum(len(l) for l in LEVELS), "a term id appears in two levels"
assert set(LEVEL_OF) == set(_ids), (
    f"unplaced: {sorted(set(_ids) - set(LEVEL_OF))} / unknown: {sorted(set(LEVEL_OF) - set(_ids))}")
