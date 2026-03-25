import Foundation

/// Mock data seeded from the 5 golden examples in CONTENT_EXAMPLES.md.
/// Used for development/preview until the real backend is connected.
/// DELETE this file when the live backend is connected.
enum MockData {

    // MARK: - Example 1: News — Transfer Confirmed (Arsenal)

    static let newsItem = ContentItem(
        id: UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!,
        teamId: "arsenal",
        type: .news,
        headline: "Big news \u{2014} Arsenal just signed a new striker and your boyfriend is probably losing his mind right now.",
        body: """
        Arsenal just made their biggest signing in years. Viktor Gyokeres \u{2014} a Swedish striker who's been absolutely tearing it up in Portugal \u{2014} is officially joining the club for around \u{00A3}85 million.

        To put that in perspective, that's one of the most expensive transfers in Arsenal's history. He scored 43 goals last season at Sporting Lisbon, which is genuinely ridiculous. For context, most strikers are happy with 15-20.

        Why it matters: Arsenal have been solid defensively (they're good at stopping the other team from scoring) but have been missing a proper goalscorer in the big games \u{2014} the ones against the top teams that decide the title. Gyokeres is supposed to be that missing piece.

        Your boyfriend's mood tonight: expect excitement levels somewhere between "kid at Christmas" and "proposing to the TV screen." This is the kind of signing fans dream about. Let him have his moment.
        """,
        talkingPoints: .stringArray([
            "So Arsenal signed this guy called Viktor Gyokeres from Sporting Lisbon \u{2014} he scored like 40 goals last season. If he brings it up, just say 'That's a massive signing' and watch his face light up.",
            "He cost around \u{00A3}85 million, which is a LOT. If you want to wind him up a bit, say 'Was he really worth that much?' \u{2014} guaranteed debate starter.",
            "The reason this is big: Arsenal have been struggling to score in big games. This guy is supposed to fix that. So if he seems over the moon, that's why.",
            "If his mates are texting about it too, you could casually drop 'I heard about the Gyokeres signing' into the group chat. Hero status."
        ]),
        kickoffTime: nil,
        emotionalContext: "exciting",
        publishedAt: Date().addingTimeInterval(-7200)
    )

    // MARK: - Example 2: Matchday — Arsenal vs Tottenham

    static let matchdayItem = ContentItem(
        id: UUID(uuidString: "b2c3d4e5-f6a7-8901-bcde-f12345678901")!,
        teamId: "arsenal",
        type: .matchday,
        headline: "Derby day. Arsenal vs Tottenham tonight and honestly, don't be surprised if he can't eat dinner.",
        body: """
        It's North London Derby day, which is basically the Super Bowl of Arsenal's season (okay not quite, but emotionally it's up there). Arsenal are hosting Tottenham at the Emirates tonight at 17:30, and your boyfriend has probably been thinking about this all week.

        Here's the deal: Arsenal and Tottenham are from the same part of London and they've been rivals for over a century. It's not just about football \u{2014} it's about bragging rights. If Arsenal win, he gets to gloat to any Spurs-supporting mates. If they lose, he will be inconsolable. There is no middle ground.

        Good news: Arsenal are in great form. They've won 4 of their last 5 games, they're sitting 2nd in the league, and they haven't lost to Spurs at home since 2022. Saka has been their best player this season with 12 goals, and big games are where he shines.

        The worry? Tottenham have actually been decent lately too. They've won their last 3 away games, and Son Heung-min (their captain, you might recognise him from those supermarket ads) always seems to score against Arsenal.

        Tonight's atmosphere at home: expect pacing, shouting at the TV, and absolutely zero attention directed at anything else for about two hours. This is normal. Bring snacks.
        """,
        talkingPoints: .matchday(MatchdayTalkingPoints(
            regular: [
                "This is THE rivalry. Arsenal and Tottenham are both from North London and they genuinely despise each other. Think of it like two siblings who've been competing since birth. Bring it up and he'll have opinions.",
                "If you want to seem like you're paying attention, ask him 'How do you think Saka's going to do tonight?' \u{2014} Saka is Arsenal's star player and this is the kind of game where he usually turns up.",
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
        )),
        kickoffTime: Date().addingTimeInterval(5400),
        emotionalContext: "exciting",
        publishedAt: Date().addingTimeInterval(-3600)
    )

    // MARK: - Example 3: News — Transfer Rumour (Man Utd)

    static let transferRumourItem = ContentItem(
        id: UUID(uuidString: "c3d4e5f6-a7b8-9012-cdef-123456789012")!,
        teamId: "man_utd",
        type: .news,
        headline: "Transfer gossip alert \u{2014} there's a rumour Man United are trying to sign a midfielder from Barcelona. He'll definitely bring this up.",
        body: """
        Every transfer window, Man United fans go through the same cycle: hope, excitement, rumour overload, and then usually disappointment. We might be entering that cycle again.

        Multiple sources are reporting that Man United are in talks to sign Frenkie de Jong from Barcelona. If that name sounds familiar, it should \u{2014} this exact rumour has popped up basically every summer since 2022. It's the transfer that never quite happens.

        De Jong is a Dutch midfielder who's really good at controlling the game (think of the person at work who keeps everything running smoothly \u{2014} that's what he does on the pitch). Man United have been desperate for someone like him because their midfield has been... let's say underwhelming.

        The catch: Barcelona are reportedly asking for \u{00A3}75 million, and de Jong seems quite happy in Spain. So this could go either way. Your boyfriend will have strong opinions on whether it'll happen. Ask him \u{2014} it's a guaranteed 20-minute conversation.
        """,
        talkingPoints: .stringArray([
            "The rumour is that Man United want Frenkie de Jong from Barcelona. This has been going on for YEARS \u{2014} it's like a will-they-won't-they romance. If he mentions it, just roll your eyes and say 'Not this again' \u{2014} he'll find it hilarious.",
            "If he seems excited about it, ask 'Do you actually think it'll happen this time?' \u{2014} it's the right question because fans have been burned before. He'll appreciate that you get it.",
            "Quick context: Man United's midfield has been their weak spot. Getting de Jong would be like finally hiring a competent manager after years of chaos at work. Big upgrade.",
            "Fair warning: transfer rumours can drag on for WEEKS. If he keeps refreshing Twitter and mumbling about 'reliable sources,' this is why."
        ]),
        kickoffTime: nil,
        emotionalContext: "drama",
        publishedAt: Date().addingTimeInterval(-14400)
    )

    // MARK: - Example 4: News — Injury (West Ham)

    static let injuryItem = ContentItem(
        id: UUID(uuidString: "d4e5f6a7-b8c9-0123-defa-234567890123")!,
        teamId: "west_ham",
        type: .news,
        headline: "Heads up \u{2014} Jarrod Bowen got injured in training today. He might be a bit gutted tonight.",
        body: """
        Not great news for West Ham today. Jarrod Bowen \u{2014} who's been their most important player this season \u{2014} picked up a hamstring injury during training and is expected to miss 3-4 weeks.

        To understand why this matters: Bowen has scored 11 goals this season and created more chances than anyone else in the team. Without him, West Ham lose their biggest attacking threat. It's like removing the engine from a car \u{2014} technically it still looks like a car, but it's not going anywhere fast.

        The timing is particularly rough because West Ham play Liverpool this Saturday. Liverpool are currently top of the league and are in incredible form. Without Bowen, that's gone from "tough game" to "we might get battered."

        For you: he might be in a bad mood about this, especially as the weekend approaches. The best thing you can do is acknowledge it \u{2014} "Gutted about Bowen" goes a long way \u{2014} and resist the urge to say "it's only football." We cannot stress this enough: never say "it's only football."
        """,
        talkingPoints: .stringArray([
            "Jarrod Bowen is basically West Ham's best player \u{2014} he scores the most goals and creates the most chances. So this is a big deal, kind of like a band's lead singer pulling out of a tour.",
            "It's a hamstring injury (back of the thigh) and he could be out for 3-4 weeks. If he seems down about it, just say 'How long is Bowen out for?' \u{2014} shows you know it matters.",
            "The silver lining you can offer: 'At least it's not a long-term thing, right?' This is genuinely helpful because hamstring injuries CAN be worse. You'll sound informed and reassuring.",
            "West Ham play Liverpool this weekend without him. If he's worried about that, he's right to be \u{2014} Liverpool are top of the league. Maybe don't mention that bit though."
        ]),
        kickoffTime: nil,
        emotionalContext: "bad_news",
        publishedAt: Date().addingTimeInterval(-28800)
    )

    // MARK: - Example 5: News — Funny Story (Man Utd)

    static let funnyItem = ContentItem(
        id: UUID(uuidString: "e5f6a7b8-c9d0-1234-efab-345678901234")!,
        teamId: "man_utd",
        type: .news,
        headline: "This is more gossip than news but \u{2014} Man United's manager just said something in a press conference that fans are losing it over.",
        body: """
        Man United's manager held a press conference today ahead of this weekend's game, and he did that thing managers do where they say something that sounds calm but is actually a grenade.

        When asked about the team's recent performances, he said he's "not happy with the attitude of certain individuals" and that "changes will be made." In normal life, this would be like your boss sending an all-staff email saying "we need to have a conversation about standards." Everyone panics.

        Fans are now going through the squad player by player trying to figure out who he's talking about. Twitter is a mess. Fantasy football teams are being reshuffled. It's chaos, and it's exactly the kind of chaos football fans secretly love.

        If he brings this up tonight \u{2014} and he probably will \u{2014} you don't need to have an opinion. Just ask "Who do you think he's on about?" and then sit back. You've just bought yourself 30 minutes of him talking passionately about squad dynamics while you nod supportively.
        """,
        talkingPoints: .stringArray([
            "The manager basically said he's 'not happy with the attitude of some players' \u{2014} which in football speak means there's DRAMA behind the scenes. If he's talking about it, just say 'That sounded intense' and let him vent.",
            "This kind of thing usually means one of two things: either a player is about to get dropped (benched), or someone's getting sold. Ask him 'Who do you think he's talking about?' \u{2014} he'll have a theory.",
            "Fun angle: football press conferences are basically like reality TV. The managers drop hints, journalists try to catch them out, and fans read into every single word. He's probably been analysing the body language all afternoon."
        ]),
        kickoffTime: nil,
        emotionalContext: "funny",
        publishedAt: Date().addingTimeInterval(-43200)
    )

    // MARK: - All Items (for feed preview)

    static let allItems: [ContentItem] = [
        newsItem,
        matchdayItem,
        transferRumourItem,
        injuryItem,
        funnyItem
    ]

    static let arsenalItems: [ContentItem] = [newsItem, matchdayItem]
    static let manUtdItems: [ContentItem] = [transferRumourItem, funnyItem]
    static let westHamItems: [ContentItem] = [injuryItem]
}

// MARK: - ContentItem Convenience Initializer (for mock data)

extension ContentItem {
    /// Convenience initializer that accepts talking points directly.
    init(
        id: UUID,
        teamId: String,
        type: ContentType,
        headline: String,
        body: String,
        talkingPoints: TalkingPointsPayload,
        kickoffTime: Date?,
        emotionalContext: String?,
        publishedAt: Date
    ) {
        self.id = id
        self.teamId = teamId
        self.type = type
        self.headline = headline
        self.body = body
        self.talkingPointsRaw = talkingPoints
        self.kickoffTime = kickoffTime
        self.emotionalContext = emotionalContext
        self.publishedAt = publishedAt
    }
}
