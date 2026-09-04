import Foundation

extension ChoresFeature.State {
    /// How the house speaks on the Home.
    ///
    /// Only what is late or due today reaches the Home. Chores scheduled for
    /// next week are real, but putting them here would turn the Home into a
    /// calendar — and a Home that always has something on it is a Home nobody
    /// reads.
    func homeContribution(partnerName: String?, now: Date = Date()) -> ModuleContribution {
        let person = partnerName ?? "Your person"
        guard let currentUserID else {
            return ModuleContribution(summary: ModuleSummary(
                module: .chores,
                status: statusLine(person: person, now: now),
                target: .chores
            ))
        }

        var signals: [HomeSignal] = []
        let mine = mine(asOf: now)

        if let first = mine.first {
            let others = mine.count - 1
            let overdue = mine.filter { if case .overdue = $0.standing(asOf: now) { return true } else { return false } }
            signals.append(HomeSignal(
                id: "chores.mine",
                module: .chores,
                urgency: .needsYou,
                title: others > 0 ? "\(mine.count) things at home" : first.title,
                detail: detail(first: first, others: others, overdue: overdue.count, now: now),
                symbol: overdue.isEmpty ? "house.fill" : "exclamationmark.triangle.fill",
                at: first.dueAt,
                target: .chores,
                worldCaption: overdue.isEmpty ? nil : "The house is waiting on you."
            ))
        }

        // What your person owes the house is worth seeing, quietly. It is not a
        // prompt to chase them — there is nothing here you can act on.
        let theirs = theirs(asOf: now).filter {
            switch $0.standing(asOf: now) {
            case .overdue, .dueToday: true
            case .upcoming, .settled: false
            }
        }
        if let first = theirs.first {
            signals.append(HomeSignal(
                id: "chores.theirs",
                module: .chores,
                urgency: .waiting,
                title: theirs.count == 1 ? first.title : "\(theirs.count) things with \(person)",
                detail: "\(person)'s turn",
                symbol: "ellipsis",
                at: first.dueAt,
                target: .chores,
                worldCaption: nil
            ))
        }

        if let fresh = active.first(where: { $0.isFresh(asOf: now) && $0.lastDoneBy != currentUserID }) {
            signals.append(HomeSignal(
                id: "chores.settled.\(fresh.id)",
                module: .chores,
                urgency: .settled,
                title: fresh.title,
                detail: "\(person) took care of this",
                symbol: "checkmark.seal.fill",
                at: fresh.lastDoneAt ?? fresh.dueAt,
                target: .chores,
                worldCaption: nil
            ))
        }

        return ModuleContribution(
            signals: signals,
            summary: ModuleSummary(
                module: .chores,
                status: statusLine(person: person, now: now),
                attention: mine.count,
                isLive: false,
                target: .chores
            )
        )
    }

    private func detail(first: Chore, others: Int, overdue: Int, now: Date) -> String {
        if overdue > 0 {
            return overdue == 1 ? "Late" : "\(overdue) of them late"
        }
        return others > 0 ? "\(first.title) and \(others) more today" : "Your turn today"
    }

    private func statusLine(person: String, now: Date) -> String {
        if case .error = phase { return "Tap to reconnect" }
        let mine = mine(asOf: now).count
        if mine > 0 { return mine == 1 ? "1 for you" : "\(mine) for you" }
        let theirs = theirs(asOf: now).count
        if theirs > 0 { return "\(theirs) with \(person)" }
        return active.isEmpty ? "Nothing set up" : "All caught up"
    }
}
