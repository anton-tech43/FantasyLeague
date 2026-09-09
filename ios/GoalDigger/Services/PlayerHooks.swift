import Foundation

/// Why she would remember him.
///
/// Every squad question used to end with the same line — "When the camera finds
/// him: 'There's Moore.'" — whether the man had scored five or never played.
/// This turns the season columns on `players` (migration 100) into one honest,
/// dated sentence per player, plus the line she leaves with.
///
/// Pure and deterministic: same rows in, same copy out. Nothing here reads the
/// network, the clock or the store, so the table test at the bottom is the
/// whole test.
///
/// Rules that are not negotiable:
/// - Nothing is claimed before the club has played three games. One good
///   afternoon does not make anyone the top scorer.
/// - A tie is named as a tie. "Joint top scorer", never "top scorer".
/// - Nil is unknown, not zero. A player whose stats have not synced gets no
///   hook at all rather than the fringe line.
/// - No em-dashes, UK English, ≤ 140 characters, and no superlative about the
///   league — only about this squad this season, which is dated by saying so.
enum PlayerHooks {
    /// Where he stands, once the hooks are known.
    enum Role: Equatable { case star, regular, fringe, unknown }

    struct Hook: Equatable {
        /// The fact, for the explanation under the answer.
        let fact: String
        /// The line she says or asks. Already quoted where it is speech.
        let use: String
        let useType: QuestionUseType
    }

    struct Verdict: Equatable {
        var hooks: [Hook] = []
        var role: Role = .unknown
        var top: Hook? { hooks.first }
    }

    static let copyCap = 140

    /// Keyed by `api_player_id`.
    /// - Parameters:
    ///   - played: the club's league games played, from `standings`. Nil or
    ///     under three means every player comes back `.unknown`.
    ///   - name: how the squad pack prints this player (surname where it is
    ///     unique, the whole name where two men share one).
    static func build(players: [LiveSquadPack.Player], club: String, played: Int?,
                      name: (LiveSquadPack.Player) -> String = { LiveClubPack.shortName($0.name) })
        -> [Int: Verdict] {
        var out: [Int: Verdict] = [:]
        for p in players { out[p.api_player_id] = Verdict() }
        guard let played, played >= 3 else { return out }

        // Squad-wide leaders. `compactMap` first: a nil column is unknown, and
        // an unknown must never win or lose a ranking.
        let maxGoals = players.compactMap(\.goals).filter { $0 > 0 }.max()
        let goalLeaders = maxGoals.map { m in players.filter { $0.goals == m }.count } ?? 0
        let maxAssists = players.compactMap(\.assists).filter { $0 > 0 }.max()
        let assistLeaders = maxAssists.map { m in players.filter { $0.assists == m }.count } ?? 0
        let maxMinutes = players.compactMap(\.minutes).filter { $0 > 0 }.max()
        let minutesLeaders = maxMinutes.map { m in players.filter { $0.minutes == m }.count } ?? 0
        let keepers = players.filter { ($0.position ?? "").lowercased() == "goalkeeper" }
        let maxSaves = keepers.compactMap(\.saves).filter { $0 > 0 }.max()
        let saveLeaders = maxSaves.map { m in keepers.filter { $0.saves == m }.count } ?? 0
        let ages = players.compactMap(\.age)
        let youngest: Int? = { guard let m = ages.min(), m <= 19, ages.filter({ $0 == m }).count == 1 else { return nil }; return m }()
        let oldest: Int? = { guard let m = ages.max(), m >= 33, ages.filter({ $0 == m }).count == 1 else { return nil }; return m }()

        for p in players {
            // No column has landed for him yet. "Has he started a game?" about a
            // first-choice centre-back whose stats have not synced is worse than
            // saying nothing.
            guard p.goals != nil || p.starts != nil || p.appearances != nil || p.minutes != nil else { continue }

            let him = name(p)
            let starts = p.league_starts ?? p.starts
            let apps = p.appearances
            var hooks: [Hook] = []
            var star = false

            if let g = p.goals, let m = maxGoals, g == m {
                star = true
                let joint = goalLeaders > 1
                hooks.append(Hook(
                    fact: joint
                        ? "\(him) has \(goalWord(g)) for \(club) this season, joint top scorer in the squad."
                        : "\(him) has \(goalWord(g)) for \(club) this season, more than anyone else in the squad.",
                    use: joint
                        ? "When his name comes up: " + LiveClubPack.quote("He's joint top scorer for them this season.")
                        : "When he gets the ball: " + LiveClubPack.quote("That's \(him), he's got their goals this season."),
                    useType: .say))
            }
            if let a = p.assists, let m = maxAssists, a == m, a >= 2 {
                star = true
                hooks.append(Hook(
                    fact: assistLeaders > 1
                        ? "\(him) has set up \(a) goals for \(club) this season, joint top for assists in the squad."
                        : "\(him) has set up \(a) goals for \(club) this season, more than anyone else in the squad.",
                    use: LiveClubPack.quote("Is \(him) the one making their goals?"),
                    useType: .ask))
            }
            if p.captain == true {
                star = true
                hooks.append(Hook(
                    fact: "\(him) is \(club)'s captain. He wears the armband and does the talking to the referee.",
                    use: "At the coin toss: " + LiveClubPack.quote("\(him) is their captain, isn't he?"),
                    useType: .say))
            }
            if let mins = p.minutes, let m = maxMinutes, mins == m, minutesLeaders == 1 {
                star = true
                hooks.append(Hook(
                    fact: "\(him) has been on the pitch longer than anyone else at \(club) this season.",
                    use: LiveClubPack.quote("\(him) plays every week, doesn't he?"),
                    useType: .ask))
            }
            if let s = p.saves, let m = maxSaves, s == m, saveLeaders == 1 {
                star = true
                hooks.append(Hook(
                    fact: "\(him) has made \(s) saves for \(club) this season.",
                    use: "When he keeps one out: " + LiveClubPack.quote("He's kept them in a few games already."),
                    useType: .say))
            }
            if let g = p.goals, g >= 2, maxGoals != g {
                hooks.append(Hook(
                    fact: apps.map { "\(him) has \(goalWord(g)) in \($0) games for \(club) this season." }
                        ?? "\(him) has \(goalWord(g)) for \(club) this season.",
                    use: "When he shoots: " + LiveClubPack.quote("He's scored a few already this season."),
                    useType: .say))
            }
            if let s = starts, s == played, played >= 3 {
                star = true
                hooks.append(Hook(
                    fact: "\(him) has started all \(played) league games for \(club) this season.",
                    use: LiveClubPack.quote("Does \(him) ever get a rest?"),
                    useType: .ask))
            }
            if let a = p.age, a == youngest {
                hooks.append(Hook(
                    fact: "\(him) is \(a), the youngest in \(club)'s squad this season.",
                    use: LiveClubPack.quote("How old is \(him)?"),
                    useType: .ask))
            } else if let a = p.age, a == oldest {
                hooks.append(Hook(
                    fact: "\(him) is \(a), the oldest in \(club)'s squad this season.",
                    use: LiveClubPack.quote("\(him) is still going at \(a)."),
                    useType: .say))
            }
            let fringe = starts == 0
            if fringe {
                hooks.append(Hook(
                    fact: "\(him) has not started a league game for \(club) this season.",
                    use: LiveClubPack.quote("Has \(him) started a game yet?"),
                    useType: .ask))
            }
            // Last resort, and only when there is nothing about his football to
            // say. "\(nationality) international" is not derivable from the feed.
            if hooks.isEmpty, let n = p.nationality, !n.isEmpty {
                hooks.append(Hook(
                    fact: "\(him) is from \(n). He is in \(club)'s squad this season.",
                    use: LiveClubPack.quote("Where's \(him) from?"),
                    useType: .ask))
            }

            out[p.api_player_id] = Verdict(hooks: hooks.filter { $0.fact.count <= copyCap && $0.use.count <= copyCap },
                                           role: star ? .star : fringe ? .fringe : .regular)
        }
        return out
    }

    private static func goalWord(_ n: Int) -> String { n == 1 ? "1 goal" : "\(n) goals" }

    // MARK: - Table test

    #if DEBUG
    /// Runs once from `LiveSquadPack.build` under an assert. Cheap: ten rows.
    static func selfCheck() -> Bool {
        func p(_ id: Int, _ name: String, goals: Int? = nil, assists: Int? = nil, starts: Int? = nil,
               minutes: Int? = nil, apps: Int? = nil, saves: Int? = nil, captain: Bool? = nil,
               nationality: String? = nil, age: Int? = nil, position: String? = "Midfielder")
            -> LiveSquadPack.Player {
            LiveSquadPack.Player(api_player_id: id, name: name, position: position, photo_url: nil,
                                 number: nil, appearances: apps, minutes: minutes, team_id: "arsenal",
                                 goals: goals, assists: assists, starts: starts, saves: saves,
                                 captain: captain, nationality: nationality, age: age,
                                 league_goals: goals, league_starts: starts)
        }
        func fact(_ v: [Int: Verdict], _ id: Int) -> String { v[id]?.top?.fact ?? "" }

        // 1 + 2: a tie is a tie, and the club must have played three games.
        let tied = [p(1, "A. One", goals: 3, starts: 3, apps: 3), p(2, "B. Two", goals: 3, starts: 3, apps: 3)]
        let t = build(players: tied, club: "Arsenal", played: 3)
        guard fact(t, 1).contains("joint top scorer"), !fact(t, 1).contains("more than anyone") else { return false }
        let early = build(players: tied, club: "Arsenal", played: 2)
        guard early[1]?.role == .unknown, early[1]?.hooks.isEmpty == true else { return false }

        // 3: a sole leader says so; 4: the captain; 5: started every league game.
        let squad = [
            p(10, "V. Gyokeres", goals: 5, assists: 1, starts: 4, minutes: 360, apps: 4, position: "Striker"),
            p(11, "M. Odegaard", goals: 1, assists: 3, starts: 4, minutes: 400, apps: 4, captain: true),
            p(12, "W. Saliba", goals: 0, assists: 0, starts: 4, minutes: 300, apps: 4, position: "Defender"),
            p(13, "N. Moore", goals: 0, assists: 0, starts: 0, minutes: 12, apps: 2, nationality: "England"),
            p(14, "M. Dowman", goals: 0, assists: 0, starts: 1, minutes: 90, apps: 1, age: 16),
            p(15, "D. Raya", goals: 0, starts: 4, minutes: 360, apps: 4, saves: 11, position: "Goalkeeper"),
            p(16, "K. Nobody"),
            p(17, "O. Elder", goals: 0, assists: 0, starts: 2, minutes: 150, apps: 3, nationality: "Brazil", age: 34),
        ]
        let v = build(players: squad, club: "Arsenal", played: 4)
        guard fact(v, 10).contains("5 goals"), fact(v, 10).contains("more than anyone else"),
              v[10]?.role == .star else { return false }
        guard fact(v, 11).contains("captain") || v[11]!.hooks.contains(where: { $0.fact.contains("captain") }),
              v[11]?.role == .star else { return false }
        guard v[12]!.hooks.contains(where: { $0.fact.contains("started all 4 league games") }) else { return false }

        // 6: the fringe player is honest about it, and nationality does not
        // outrank it. 7: no stats at all is unknown, never fringe.
        guard fact(v, 13) == "Moore has not started a league game for Arsenal this season.",
              v[13]?.role == .fringe else { return false }
        guard v[16]?.role == .unknown, v[16]?.hooks.isEmpty == true else { return false }

        // 8: youngest, 9: oldest, 10: the keeper's saves.
        guard fact(v, 14).contains("the youngest"), fact(v, 17).contains("the oldest"),
              v[15]!.hooks.contains(where: { $0.fact.contains("11 saves") }) else { return false }

        // 11: nationality only when nothing else is true.
        let onlyNation = build(players: [
            p(20, "Q. Quiet", goals: 0, assists: 0, starts: 2, minutes: 100, apps: 2, nationality: "Sweden"),
            p(21, "R. Regular", goals: 1, assists: 1, starts: 4, minutes: 400, apps: 4),
        ], club: "Arsenal", played: 4)
        guard fact(onlyNation, 20).contains("from Sweden") else { return false }

        // 12: every line fits, and nobody smuggles in an em-dash.
        for verdict in Array(v.values) + Array(t.values) + Array(onlyNation.values) {
            for h in verdict.hooks where h.fact.count > copyCap || h.use.count > copyCap
                || h.fact.contains("\u{2014}") || h.use.contains("\u{2014}") { return false }
        }
        return true
    }
    #endif
}
