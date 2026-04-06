import Foundation

/// Mock data for development without backend. Based on the 5 golden examples from CONTENT_EXAMPLES.md.
/// Delete this file when connecting to live Supabase backend.
struct MockData {

    static let feed: [ContentItem] = [example1, example2, example3, example4, example5]

    // MARK: - Example 1: News — Transfer Confirmed (Arsenal)

    static let example1: ContentItem = {
        let json = """
        {
            "id": "a1b2c3d4-e5f6-7890-abcd-000000000001",
            "team_id": "arsenal",
            "type": "news",
            "headline": "Big news — Arsenal just signed a new striker and your boyfriend is probably losing his mind right now.",
            "body": "Arsenal just made their biggest signing in years. Viktor Gyokeres — a Swedish striker who's been absolutely tearing it up in Portugal — is officially joining the club for around £85 million.\\n\\nTo put that in perspective, that's one of the most expensive transfers in Arsenal's history. He scored 43 goals last season at Sporting Lisbon, which is genuinely ridiculous. For context, most strikers are happy with 15-20.\\n\\nWhy it matters: Arsenal have been solid defensively (they're good at stopping the other team from scoring) but have been missing a proper goalscorer in the big games — the ones against the top teams that decide the title. Gyokeres is supposed to be that missing piece.\\n\\nYour boyfriend's mood tonight: expect excitement levels somewhere between \\"kid at Christmas\\" and \\"proposing to the TV screen.\\" This is the kind of signing fans dream about. Let him have his moment.",
            "talking_points": [
                "So Arsenal signed this guy called Viktor Gyokeres from Sporting Lisbon — he scored like 40 goals last season. If he brings it up, just say 'That's a massive signing' and watch his face light up.",
                "He cost around £85 million, which is a LOT. If you want to wind him up a bit, say 'Was he really worth that much?' — guaranteed debate starter.",
                "The reason this is big: Arsenal have been struggling to score in big games. This guy is supposed to fix that. So if he seems over the moon, that's why.",
                "If his mates are texting about it too, you could casually drop 'I heard about the Gyokeres signing' into the group chat. Hero status."
            ],
            "kickoff_time": null,
            "emotional_context": "exciting",
            "published_at": "\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200)))"
        }
        """.data(using: .utf8)!
        return try! mockDecoder.decode(ContentItem.self, from: json)
    }()

    // MARK: - Example 2: Matchday — Big Rivalry (Arsenal vs Tottenham)

    static let example2: ContentItem = {
        let kickoff = Date().addingTimeInterval(3600 * 4) // 4 hours from now
        let json = """
        {
            "id": "a1b2c3d4-e5f6-7890-abcd-000000000002",
            "team_id": "arsenal",
            "type": "matchday",
            "headline": "Derby day. Arsenal vs Tottenham tonight and honestly, don't be surprised if he can't eat dinner.",
            "body": "It's North London Derby day, which is basically the Super Bowl of Arsenal's season (okay not quite, but emotionally it's up there). Arsenal are hosting Tottenham at the Emirates tonight at 17:30, and your boyfriend has probably been thinking about this all week.\\n\\nHere's the deal: Arsenal and Tottenham are from the same part of London and they've been rivals for over a century. It's not just about football — it's about bragging rights. If Arsenal win, he gets to gloat to any Spurs-supporting mates. If they lose, he will be inconsolable. There is no middle ground.\\n\\nGood news: Arsenal are in great form. They've won 4 of their last 5 games, they're sitting 2nd in the league, and they haven't lost to Spurs at home since 2022. Saka has been their best player this season with 12 goals, and big games are where he shines.\\n\\nThe worry? Tottenham have actually been decent lately too. They've won their last 3 away games, and Son Heung-min (their captain, you might recognise him from those supermarket ads) always seems to score against Arsenal.\\n\\nTonight's atmosphere at home: expect pacing, shouting at the TV, and absolutely zero attention directed at anything else for about two hours. This is normal. Bring snacks.",
            "talking_points": {
                "regular": [
                    "This is THE rivalry. Arsenal and Tottenham are both from North London and they genuinely despise each other. Think of it like two siblings who've been competing since birth. Bring it up and he'll have opinions.",
                    "If you want to seem like you're paying attention, ask him 'How do you think Saka's going to do tonight?' — Saka is Arsenal's star player and this is the kind of game where he usually turns up.",
                    "Fun fact you can casually drop: Arsenal haven't lost to Spurs at home in over 3 years. If he's nervous, remind him of that. Instant brownie points.",
                    "The game kicks off at 17:30. If he goes quiet about an hour before, that's normal. It's not about you. He's mentally preparing."
                ],
                "post_match": {
                    "if_they_win": "That was massive, right?! You must be buzzing.",
                    "if_they_lose": "Unlucky. They'll bounce back though.",
                    "bold_prediction": "2-1 Arsenal"
                },
                "metadata": {
                    "pre_match_mood": "nervous",
                    "rivalry_level": "derby"
                }
            },
            "kickoff_time": "\(ISO8601DateFormatter().string(from: kickoff))",
            "emotional_context": "exciting",
            "published_at": "\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)))"
        }
        """.data(using: .utf8)!
        return try! mockDecoder.decode(ContentItem.self, from: json)
    }()

    // MARK: - Example 3: News — Transfer Rumour (Man Utd)

    static let example3: ContentItem = {
        let json = """
        {
            "id": "a1b2c3d4-e5f6-7890-abcd-000000000003",
            "team_id": "man_utd",
            "type": "news",
            "headline": "Transfer gossip alert — there's a rumour Man United are trying to sign a midfielder from Barcelona. He'll definitely bring this up.",
            "body": "Every transfer window, Man United fans go through the same cycle: hope, excitement, rumour overload, and then usually disappointment. We might be entering that cycle again.\\n\\nMultiple sources are reporting that Man United are in talks to sign Frenkie de Jong from Barcelona. If that name sounds familiar, it should — this exact rumour has popped up basically every summer since 2022. It's the transfer that never quite happens.\\n\\nDe Jong is a Dutch midfielder who's really good at controlling the game (think of the person at work who keeps everything running smoothly — that's what he does on the pitch). Man United have been desperate for someone like him because their midfield has been... let's say underwhelming.\\n\\nThe catch: Barcelona are reportedly asking for £75 million, and de Jong seems quite happy in Spain. So this could go either way. Your boyfriend will have strong opinions on whether it'll happen. Ask him — it's a guaranteed 20-minute conversation.",
            "talking_points": [
                "The rumour is that Man United want Frenkie de Jong from Barcelona. This has been going on for YEARS — it's like a will-they-won't-they romance. If he mentions it, just roll your eyes and say 'Not this again' — he'll find it hilarious.",
                "If he seems excited about it, ask 'Do you actually think it'll happen this time?' — it's the right question because fans have been burned before. He'll appreciate that you get it.",
                "Quick context: Man United's midfield has been their weak spot. Getting de Jong would be like finally hiring a competent manager after years of chaos at work. Big upgrade.",
                "Fair warning: transfer rumours can drag on for WEEKS. If he keeps refreshing Twitter and mumbling about 'reliable sources,' this is why."
            ],
            "kickoff_time": null,
            "emotional_context": "drama",
            "published_at": "\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)))"
        }
        """.data(using: .utf8)!
        return try! mockDecoder.decode(ContentItem.self, from: json)
    }()

    // MARK: - Example 4: News — Injury (West Ham)

    static let example4: ContentItem = {
        let json = """
        {
            "id": "a1b2c3d4-e5f6-7890-abcd-000000000004",
            "team_id": "west_ham",
            "type": "news",
            "headline": "Heads up — Jarrod Bowen got injured in training today. He might be a bit gutted tonight.",
            "body": "Not great news for West Ham today. Jarrod Bowen — who's been their most important player this season — picked up a hamstring injury during training and is expected to miss 3-4 weeks.\\n\\nTo understand why this matters: Bowen has scored 11 goals this season and created more chances than anyone else in the team. Without him, West Ham lose their biggest attacking threat. It's like removing the engine from a car — technically it still looks like a car, but it's not going anywhere fast.\\n\\nThe timing is particularly rough because West Ham play Liverpool this Saturday. Liverpool are currently top of the league and are in incredible form. Without Bowen, that's gone from \\"tough game\\" to \\"we might get battered.\\"\\n\\nFor you: he might be in a bad mood about this, especially as the weekend approaches. The best thing you can do is acknowledge it — \\"Gutted about Bowen\\" goes a long way — and resist the urge to say \\"it's only football.\\" We cannot stress this enough: never say \\"it's only football.\\"",
            "talking_points": [
                "Jarrod Bowen is basically West Ham's best player — he scores the most goals and creates the most chances. So this is a big deal, kind of like a band's lead singer pulling out of a tour.",
                "It's a hamstring injury (back of the thigh) and he could be out for 3-4 weeks. If he seems down about it, just say 'How long is Bowen out for?' — shows you know it matters.",
                "The silver lining you can offer: 'At least it's not a long-term thing, right?' This is genuinely helpful because hamstring injuries CAN be worse. You'll sound informed and reassuring.",
                "West Ham play Liverpool this weekend without him. If he's worried about that, he's right to be — Liverpool are top of the league. Maybe don't mention that bit though."
            ],
            "kickoff_time": null,
            "emotional_context": "bad_news",
            "published_at": "\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-172800)))"
        }
        """.data(using: .utf8)!
        return try! mockDecoder.decode(ContentItem.self, from: json)
    }()

    // MARK: - Example 5: News — Funny Story (Man Utd)

    static let example5: ContentItem = {
        let json = """
        {
            "id": "a1b2c3d4-e5f6-7890-abcd-000000000005",
            "team_id": "man_utd",
            "type": "news",
            "headline": "This is more gossip than news but — Man United's manager just said something in a press conference that fans are losing it over.",
            "body": "Man United's manager held a press conference today ahead of this weekend's game, and he did that thing managers do where they say something that sounds calm but is actually a grenade.\\n\\nWhen asked about the team's recent performances, he said he's \\"not happy with the attitude of certain individuals\\" and that \\"changes will be made.\\" In normal life, this would be like your boss sending an all-staff email saying \\"we need to have a conversation about standards.\\" Everyone panics.\\n\\nFans are now going through the squad player by player trying to figure out who he's talking about. Twitter is a mess. Fantasy football teams are being reshuffled. It's chaos, and it's exactly the kind of chaos football fans secretly love.\\n\\nIf he brings this up tonight — and he probably will — you don't need to have an opinion. Just ask \\"Who do you think he's on about?\\" and then sit back. You've just bought yourself 30 minutes of him talking passionately about squad dynamics while you nod supportively.",
            "talking_points": [
                "The manager basically said he's 'not happy with the attitude of some players' — which in football speak means there's DRAMA behind the scenes. If he's talking about it, just say 'That sounded intense' and let him vent.",
                "This kind of thing usually means one of two things: either a player is about to get dropped (benched), or someone's getting sold. Ask him 'Who do you think he's talking about?' — he'll have a theory.",
                "Fun angle: football press conferences are basically like reality TV. The managers drop hints, journalists try to catch them out, and fans read into every single word. He's probably been analysing the body language all afternoon."
            ],
            "kickoff_time": null,
            "emotional_context": "funny",
            "published_at": "\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-259200)))"
        }
        """.data(using: .utf8)!
        return try! mockDecoder.decode(ContentItem.self, from: json)
    }()

    // MARK: - Decoder

    private static let mockDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = fractionalFormatter.date(from: dateString) { return date }
            if let date = plainFormatter.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
        }
        return decoder
    }()
}
