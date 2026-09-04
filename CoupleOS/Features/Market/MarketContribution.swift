import Foundation

extension MarketFeature.State {
    /// How the Market speaks on the Home.
    ///
    /// Only a run or an open ask is loud enough to reach the Home. A list that
    /// is merely long stays in the area tile, because a list nobody is standing
    /// in front of is not news.
    func homeContribution(
        strings: Strings,
        partnerName: String?,
        now: Date = Date()
    ) -> ModuleContribution {
        let copy = strings.market
        var signals: [HomeSignal] = []

        if let run = partnerRun {
            signals.append(HomeSignal(
                id: "market.run.\(run.id)",
                module: .market,
                urgency: .live,
                title: copy.signalPartnerRunTitle(partnerName),
                detail: pending.isEmpty
                    ? copy.signalRunDetailEmpty
                    : copy.signalRunDetailPending(pending.count),
                symbol: "figure.walk.motion",
                at: run.startedAt,
                target: .market,
                worldCaption: copy.captionPartnerRun(partnerName)
            ))
        } else if let run = myRun {
            signals.append(HomeSignal(
                id: "market.run.\(run.id)",
                module: .market,
                urgency: .live,
                title: copy.signalMyRunTitle,
                detail: pending.isEmpty
                    ? copy.signalMyRunDetailEmpty
                    : copy.signalMyRunDetailPending(pending.count),
                symbol: "basket.fill",
                at: run.startedAt,
                target: .market,
                worldCaption: copy.captionMyRun(partnerName)
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
                    ? copy.signalAsksTitle(partnerName, currentAsks.count)
                    : ask.name,
                detail: others > 0
                    ? copy.signalAsksDetailMany(ask.name, others)
                    : copy.signalAsksDetailOne(partnerName),
                symbol: "hand.raised.fill",
                at: ask.requestedAt,
                target: .market,
                worldCaption: copy.captionAsks(partnerName)
            ))
        }

        return ModuleContribution(
            signals: signals,
            summary: ModuleSummary(
                module: .market,
                status: statusLine(copy, partnerName, now: now),
                attention: currentAsks.count,
                isLive: activeRun != nil,
                target: .market
            )
        )
    }

    private func statusLine(
        _ copy: Strings.Market,
        _ partnerName: String?,
        now: Date
    ) -> String {
        if case .error = phase { return copy.statusReconnect }
        if partnerRun != nil { return copy.statusPartnerThere(partnerName) }
        if myRun != nil { return copy.statusYouThere }
        // The tile counts what is current. Stale items are still on the list,
        // but promising "12 to bring" when nine of them are months old is a lie
        // the Couple learns to distrust.
        let current = pending.count - stale(asOf: now).count
        guard current > 0 else {
            return pending.isEmpty ? copy.statusNothingToBring : copy.statusNothingCurrent
        }
        return copy.statusToBring(current)
    }
}
