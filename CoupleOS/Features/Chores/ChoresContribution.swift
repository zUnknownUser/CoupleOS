import Foundation

extension ChoresFeature.State {
    /// How the house speaks on the Home.
    ///
    /// Only what is late or due today reaches the Home. Chores scheduled for
    /// next week are real, but putting them here would turn the Home into a
    /// calendar — and a Home that always has something on it is a Home nobody
    /// reads.
    func homeContribution(
        strings: Strings,
        partnerName: String?,
        now: Date = Date()
    ) -> ModuleContribution {
        let copy = strings.chores
        guard let currentUserID else {
            return ModuleContribution(summary: ModuleSummary(
                module: .chores,
                status: statusLine(copy, partnerName, now: now),
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
                title: others > 0 ? copy.signalMineTitleMany(mine.count) : first.title,
                detail: detail(copy, first: first, others: others, overdue: overdue.count),
                symbol: overdue.isEmpty ? "house.fill" : "exclamationmark.triangle.fill",
                at: first.dueAt,
                target: .chores,
                worldCaption: overdue.isEmpty ? nil : copy.captionOverdue
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
                title: theirs.count == 1
                    ? first.title
                    : copy.signalTheirsTitleMany(theirs.count, partnerName),
                detail: copy.signalTheirsDetail(partnerName),
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
                detail: copy.signalSettledDetail(partnerName),
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
                status: statusLine(copy, partnerName, now: now),
                attention: mine.count,
                isLive: false,
                target: .chores
            )
        )
    }

    private func detail(
        _ copy: Strings.Chores,
        first: Chore,
        others: Int,
        overdue: Int
    ) -> String {
        if overdue > 0 { return copy.detailLate(overdue) }
        return others > 0
            ? copy.detailOthersToday(first.title, others)
            : copy.detailYourTurnToday
    }

    private func statusLine(
        _ copy: Strings.Chores,
        _ partnerName: String?,
        now: Date
    ) -> String {
        if case .error = phase { return copy.statusReconnect }
        let mine = mine(asOf: now).count
        if mine > 0 { return copy.statusForYou(mine) }
        let theirs = theirs(asOf: now).count
        if theirs > 0 { return copy.statusWithPartner(theirs, partnerName) }
        return active.isEmpty ? copy.statusNothingSetUp : copy.statusAllCaughtUp
    }
}
