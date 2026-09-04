import Foundation

extension MarketFeature.State {
    /// How the Market speaks on the Home.
    ///
    /// Only a run or an open ask is loud enough to reach the Home. A list that
    /// is merely long stays in the area tile, because a list nobody is standing
    /// in front of is not news.
    func homeContribution(partnerName: String?, now: Date = Date()) -> ModuleContribution {
        let person = partnerName ?? "Your person"
        var signals: [HomeSignal] = []

        if let run = partnerRun {
            signals.append(HomeSignal(
                id: "market.run.\(run.id)",
                module: .market,
                urgency: .live,
                title: "\(person) is at the market",
                detail: pending.isEmpty
                    ? "Nothing on the list yet — ask for something"
                    : "\(pending.count) \(pending.count == 1 ? "thing" : "things") to bring · add anything?",
                symbol: "figure.walk.motion",
                at: run.startedAt,
                target: .market,
                worldCaption: "\(person) is out in the world. Now is the moment."
            ))
        } else if let run = myRun {
            signals.append(HomeSignal(
                id: "market.run.\(run.id)",
                module: .market,
                urgency: .live,
                title: "You're at the market",
                detail: pending.isEmpty
                    ? "Everything is gathered"
                    : "\(pending.count) still to gather",
                symbol: "basket.fill",
                at: run.startedAt,
                target: .market,
                worldCaption: "You're out there. \(person) can still reach you."
            ))
        }

        // While you are the one shopping, the run card already carries the asks.
        // Stale asks are skipped: something nobody acted on for two weeks has
        // stopped being news, and letting it shout forever is how a Home earns
        // being ignored.
        let currentAsks = requestsForMe.filter { !$0.isStale(asOf: now) }
        if myRun == nil, let ask = currentAsks.first {
            let others = currentAsks.count - 1
            signals.append(HomeSignal(
                id: "market.asks",
                module: .market,
                urgency: .needsYou,
                title: others > 0
                    ? "\(person) asked for \(currentAsks.count) things"
                    : ask.name,
                detail: others > 0
                    ? "\(ask.name) and \(others) more"
                    : "\(person) asked you to bring this",
                symbol: "hand.raised.fill",
                at: ask.requestedAt,
                target: .market,
                worldCaption: "\(person) is counting on you for something small."
            ))
        }

        return ModuleContribution(
            signals: signals,
            summary: summary(person: person, asks: currentAsks.count, now: now)
        )
    }

    private func summary(person: String, asks: Int, now: Date) -> ModuleSummary {
        ModuleSummary(
            module: .market,
            status: statusLine(person: person, now: now),
            attention: asks,
            isLive: activeRun != nil,
            target: .market
        )
    }

    private func statusLine(person: String, now: Date) -> String {
        if case .error = phase { return "Tap to reconnect" }
        if partnerRun != nil { return "\(person) is there now" }
        if myRun != nil { return "You're there now" }
        // The tile counts what is current. Stale items are still on the list,
        // but promising "12 to bring" when nine of them are months old is a lie
        // the Couple learns to distrust.
        let current = pending.count - stale(asOf: now).count
        guard current > 0 else {
            return pending.isEmpty ? "Nothing to bring" : "Nothing current"
        }
        return "\(current) to bring"
    }
}
