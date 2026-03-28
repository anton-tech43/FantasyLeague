import Foundation

enum MockData {
    // MARK: - Example 1: News — Transfer Confirmed (Arsenal)
    static let arsenalTransfer = ContentItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        teamId: "arsenal",
        type: .news,
        headline: "Big news — Arsenal just signed a new striker and your boyfriend is probably losing his mind right now.",
        body: """
        Arsenal just made their biggest signing in years. Viktor Gyokeres — a Swedish striker who's been \
        absolutely tearing it up in Portugal — is officially joining the club for around £85 million.

        To put that in perspective, that's one of the most expensive transfers in Arsenal's history. He scored \
        43 goals last season at Sporting Lisbon, which is genuinely ridiculous. For context, most strikers are \
        happy with 15-20.

        Why it matters: Arsenal have been solid defensively (they're good at stopping the other team from \
        scoring) but have been missing a proper goalscorer in the big games — the ones against the top teams \
        that decide the title. Gyokeres is supposed to be that missing piece.

        Your boyfriend's mood tonight: expect excitement levels somewhere between "kid at Christmas" and \
        "proposing to the TV screen." This is the kind of signing fans dream about. Let him have his moment.
        """,
        talkingPoints: [
            "So Arsenal signed this guy called Viktor Gyokeres from Sporting Lisbon — he scored like 40 goals last season. If he brings it up, just say 'That's a massive signing' and watch his face light up.",
            "He cost around £85 million, which is a LOT. If you want to wind him up a bit, say 'Was he really worth that much?' — guaranteed debate starter.",
            "The reason this is big: Arsenal have been struggling to score in big games. This guy is supposed to fix that. So if he seems over the moon, that's why.",
            "If his mates are texting about it too, you could casually drop 'I heard about the Gyokeres signing' into the group chat. Hero status."
        ],
        emotionalContext: "exciting",
        publishedAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
    )

    // MARK: - Example 2: Matchday — Big Rivalry (Arsenal vs Tottenham)
    static let arsenalDerby = ContentItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        teamId: "arsenal",
        type: .matchday,
        headline: "Derby day. Arsenal vs Tottenham tonight and honestly, don't be surprised if he can't eat dinner.",
        body: """
        It's North London Derby day, which is basically the Super Bowl of Arsenal's season (okay not quite, \
        but emotionally it's up there). Arsenal are hosting Tottenham at the Emirates tonight at 17:30, and \
        your boyfriend has probably been thinking about this all week.

        Here's the deal: Arsenal and Tottenham are from the same part of London and they've been rivals for \
        over a century. It's not just about football — it's about bragging rights. If Arsenal win, he gets to \
        gloat to any Spurs-supporting mates. If they lose, he will be inconsolable. There is no middle ground.

        Good news: Arsenal are in great form. They've won 4 of their last 5 games, they're sitting 2nd in the \
        league, and they haven't lost to Spurs at home since 2022. Saka has been their best player this season \
        with 12 goals, and big games are where he shines.

        The worry? Tottenham have actually been decent lately too. They've won their last 3 away games, and \
        Son Heung-min (their captain, you might recognise him from those supermarket ads) always seems to \
        score against Arsenal.

        Tonight's atmosphere at home: expect pacing, shouting at the TV, and absolutely zero attention \
        directed at anything else for about two hours. This is normal. Bring snacks.
        """,
        talkingPoints: [
            "This is THE rivalry. Arsenal and Tottenham are both from North London and they genuinely despise each other. Think of it like two siblings who've been competing since birth. Bring it up and he'll have opinions.",
            "If you want to seem like you're paying attention, ask him 'How do you think Saka's going to do tonight?' — Saka is Arsenal's star player and this is the kind of game where he usually turns up.",
            "Fun fact you can casually drop: Arsenal haven't lost to Spurs at home in over 3 years. If he's nervous, remind him of that. Instant brownie points.",
            "The game kicks off at 17:30. If he goes quiet about an hour before, that's normal. It's not about you. He's mentally preparing."
        ],
        matchdayData: MatchdayTalkingPoints(
            regular: [
                "This is THE rivalry. Arsenal and Tottenham are both from North London and they genuinely despise each other. Think of it like two siblings who've been competing since birth. Bring it up and he'll have opinions.",
                "If you want to seem like you're paying attention, ask him 'How do you think Saka's going to do tonight?' — Saka is Arsenal's star player and this is the kind of game where he usually turns up.",
                "Fun fact you can casually drop: Arsenal haven't lost to Spurs at home in over 3 years. If he's nervous, remind him of that. Instant brownie points.",
                "The game kicks off at 17:30. If he goes quiet about an hour before, that's normal. It's not about you. He's mentally preparing."
            ],
            postMatch: PostMatchCheatSheet(
                ifTheyWin: "That was massive, right?! You must be buzzing.",
                ifTheyLose: "Unlucky. They'll bounce back though.",
                boldPrediction: "2-1 Arsenal"
            ),
            metadata: MatchdayMetadata(
                preMatchMood: "nervous",
                rivalryLevel: "derby"
            )
        ),
        kickoffTime: Calendar.current.date(bySettingHour: 17, minute: 30, second: 0, of: Date()),
        emotionalContext: "exciting",
        publishedAt: Calendar.current.date(byAdding: .hour, value: -5, to: Date())!
    )

    // MARK: - Example 3: News — Transfer Rumour (Manchester United)
    static let manUtdRumour = ContentItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        teamId: "man_utd",
        type: .news,
        headline: "Transfer gossip alert — there's a rumour Man United are trying to sign a midfielder from Barcelona. He'll definitely bring this up.",
        body: """
        Every transfer window, Man United fans go through the same cycle: hope, excitement, rumour overload, \
        and then usually disappointment. We might be entering that cycle again.

        Multiple sources are reporting that Man United are in talks to sign Frenkie de Jong from Barcelona. \
        If that name sounds familiar, it should — this exact rumour has popped up basically every summer since \
        2022. It's the transfer that never quite happens.

        De Jong is a Dutch midfielder who's really good at controlling the game (think of the person at work \
        who keeps everything running smoothly — that's what he does on the pitch). Man United have been \
        desperate for someone like him because their midfield has been... let's say underwhelming.

        The catch: Barcelona are reportedly asking for £75 million, and de Jong seems quite happy in Spain. \
        So this could go either way. Your boyfriend will have strong opinions on whether it'll happen. Ask \
        him — it's a guaranteed 20-minute conversation.
        """,
        talkingPoints: [
            "The rumour is that Man United want Frenkie de Jong from Barcelona. This has been going on for YEARS — it's like a will-they-won't-they romance. If he mentions it, just roll your eyes and say 'Not this again' — he'll find it hilarious.",
            "If he seems excited about it, ask 'Do you actually think it'll happen this time?' — it's the right question because fans have been burned before. He'll appreciate that you get it.",
            "Quick context: Man United's midfield has been their weak spot. Getting de Jong would be like finally hiring a competent manager after years of chaos at work. Big upgrade.",
            "Fair warning: transfer rumours can drag on for WEEKS. If he keeps refreshing Twitter and mumbling about 'reliable sources,' this is why."
        ],
        emotionalContext: "drama",
        publishedAt: Calendar.current.date(byAdding: .hour, value: -8, to: Date())!
    )

    // MARK: - Example 4: News — Injury to Key Player (West Ham)
    static let westHamInjury = ContentItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        teamId: "west_ham",
        type: .news,
        headline: "Heads up — Jarrod Bowen got injured in training today. He might be a bit gutted tonight.",
        body: """
        Not great news for West Ham today. Jarrod Bowen — who's been their most important player this \
        season — picked up a hamstring injury during training and is expected to miss 3-4 weeks.

        To understand why this matters: Bowen has scored 11 goals this season and created more chances than \
        anyone else in the team. Without him, West Ham lose their biggest attacking threat. It's like removing \
        the engine from a car — technically it still looks like a car, but it's not going anywhere fast.

        The timing is particularly rough because West Ham play Liverpool this Saturday. Liverpool are currently \
        top of the league and are in incredible form. Without Bowen, that's gone from "tough game" to "we \
        might get battered."

        For you: he might be in a bad mood about this, especially as the weekend approaches. The best thing \
        you can do is acknowledge it — "Gutted about Bowen" goes a long way — and resist the urge to say \
        "it's only football." We cannot stress this enough: never say "it's only football."
        """,
        talkingPoints: [
            "Jarrod Bowen is basically West Ham's best player — he scores the most goals and creates the most chances. So this is a big deal, kind of like a band's lead singer pulling out of a tour.",
            "It's a hamstring injury (back of the thigh) and he could be out for 3-4 weeks. If he seems down about it, just say 'How long is Bowen out for?' — shows you know it matters.",
            "The silver lining you can offer: 'At least it's not a long-term thing, right?' This is genuinely helpful because hamstring injuries CAN be worse. You'll sound informed and reassuring.",
            "West Ham play Liverpool this weekend without him. If he's worried about that, he's right to be — Liverpool are top of the league. Maybe don't mention that bit though."
        ],
        emotionalContext: "bad_news",
        publishedAt: Calendar.current.date(byAdding: .hour, value: -12, to: Date())!
    )

    // MARK: - Example 5: News — Low-Key Funny Story (Manchester United)
    static let manUtdPressConference = ContentItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        teamId: "man_utd",
        type: .news,
        headline: "This is more gossip than news but — Man United's manager just said something in a press conference that fans are losing it over.",
        body: """
        Man United's manager held a press conference today ahead of this weekend's game, and he did that \
        thing managers do where they say something that sounds calm but is actually a grenade.

        When asked about the team's recent performances, he said he's "not happy with the attitude of certain \
        individuals" and that "changes will be made." In normal life, this would be like your boss sending an \
        all-staff email saying "we need to have a conversation about standards." Everyone panics.

        Fans are now going through the squad player by player trying to figure out who he's talking about. \
        Twitter is a mess. Fantasy football teams are being reshuffled. It's chaos, and it's exactly the \
        kind of chaos football fans secretly love.

        If he brings this up tonight — and he probably will — you don't need to have an opinion. Just ask \
        "Who do you think he's on about?" and then sit back. You've just bought yourself 30 minutes of him \
        talking passionately about squad dynamics while you nod supportively.
        """,
        talkingPoints: [
            "The manager basically said he's 'not happy with the attitude of some players' — which in football speak means there's DRAMA behind the scenes. If he's talking about it, just say 'That sounded intense' and let him vent.",
            "This kind of thing usually means one of two things: either a player is about to get dropped (benched), or someone's getting sold. Ask him 'Who do you think he's talking about?' — he'll have a theory.",
            "Fun angle: football press conferences are basically like reality TV. The managers drop hints, journalists try to catch them out, and fans read into every single word. He's probably been analysing the body language all afternoon."
        ],
        emotionalContext: "funny",
        publishedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    )

    // MARK: - Grouped Access

    /// All 5 golden examples
    static let allItems: [ContentItem] = [
        arsenalTransfer,
        arsenalDerby,
        manUtdRumour,
        westHamInjury,
        manUtdPressConference
    ]

    /// Filter by team
    static func items(for team: Team) -> [ContentItem] {
        allItems.filter { $0.teamId == team.rawValue }
    }

    /// Arsenal examples (2 items: transfer + derby)
    static let arsenalItems: [ContentItem] = [arsenalTransfer, arsenalDerby]

    /// Man United examples (2 items: rumour + press conference)
    static let manUtdItems: [ContentItem] = [manUtdRumour, manUtdPressConference]

    /// West Ham examples (1 item: injury)
    static let westHamItems: [ContentItem] = [westHamInjury]
}
