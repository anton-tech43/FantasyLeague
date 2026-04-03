import Foundation

// MARK: - Mock Data
// 5 golden examples for development. Talking points are written as
// CONVERSATION OPENERS — things she'd actually say to start a dialogue,
// not facts to memorize. Leading with curiosity, not information.
//
// For other agents: Pipeline Agent needs to update Claude prompts to
// generate this conversation-opener style. Current prompts produce
// fact-based talking points. See DEVELOPMENT_NOTES.md.

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
            "I saw Arsenal signed that Sporting goal scorer — do you think he'll actually perform in the Premier League?",
            "Was Gyokeres really worth £85 million though? That seems like a lot for someone from Portugal.",
            "Do you think this means Arsenal are actually going to challenge for the title now?",
            "I saw the Gyokeres thing on my phone — are you happy or do you think they overpaid?"
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
            "So why is the Tottenham game such a big deal? Is it like the biggest match of the season?",
            "How do you think Saka will do tonight? I heard he usually shows up for the big ones.",
            "Didn't Arsenal beat Tottenham every time recently? Should you even be nervous?",
            "What happens if they lose tonight — does it actually matter for the league or is it more of a pride thing?"
        ],
        matchdayData: MatchdayTalkingPoints(
            regular: [
                "So why is the Tottenham game such a big deal? Is it like the biggest match of the season?",
                "How do you think Saka will do tonight? I heard he usually shows up for the big ones.",
                "Didn't Arsenal beat Tottenham every time recently? Should you even be nervous?",
                "What happens if they lose tonight — does it actually matter for the league or is it more of a pride thing?"
            ],
            postMatch: PostMatchCheatSheet(
                ifTheyWin: "That was massive, right?! You must be buzzing.",
                ifTheyLose: "Unlucky. They'll bounce back though — it's still early, right?",
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
            "Not the de Jong thing again?! Do you actually think it's happening this time or is it the same as every year?",
            "Why do United keep going back for de Jong when he clearly doesn't want to leave? Is there no one else?",
            "If they actually sign him, would that fix midfield or do they need more than one player?",
            "I saw something about de Jong to United — are the sources reliable or is it just Twitter nonsense?"
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
            "I saw Bowen got injured — how long is he out for? That must be frustrating.",
            "Is there anyone who can replace him or is it one of those situations where you're just stuck?",
            "At least it's only a few weeks, right? Could have been way worse for a hamstring.",
            "Are you worried about the Liverpool game without him or do you think they'll manage?"
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
            "Did you see what the manager said about 'certain individuals'? Who do you think he's talking about?",
            "Do you think someone's actually getting dropped or is it just mind games?",
            "I saw the press conference clip — that was so passive aggressive. Is he always like that?"
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
