import Foundation

extension DecisionsFeature.State {
    /// How Decisions speaks on the Home.
    ///
    /// Each question waiting on you keeps its own words — a decision *is* its
    /// title, and collapsing them into a count would throw away the only thing
    /// that makes one worth answering before another.
    func homeContribution(strings: Strings, partnerName: String?) -> ModuleContribution {
        let copy = strings.decisions
        var signals = needsMyResponse.map { decision in
            HomeSignal(
                id: "decisions.needs.\(decision.id)",
                module: .decisions,
                urgency: .needsYou,
                title: decision.title,
                detail: copy.signalNeedsDetail(partnerName),
                symbol: "arrow.triangle.branch",
                at: decision.createdAt,
                target: .decision(id: decision.id),
                worldCaption: nil
            )
        }

        // Waiting collapses: none of it is actionable, so it earns one line.
        if let oldest = waitingForPartner.min(by: { $0.createdAt < $1.createdAt }) {
            let count = waitingForPartner.count
            signals.append(HomeSignal(
                id: "decisions.waiting",
                module: .decisions,
                urgency: .waiting,
                title: count == 1
                    ? oldest.title
                    : copy.signalWaitingTitleMany(count, partnerName),
                detail: count == 1
                    ? copy.signalWaitingDetailOne(partnerName)
                    : copy.signalWaitingDetailMany,
                symbol: "ellipsis",
                at: oldest.createdAt,
                target: .decision(id: oldest.id),
                worldCaption: nil
            ))
        }

        if let fresh = recent.first(where: { $0.isFresh }) {
            signals.append(HomeSignal(
                id: "decisions.settled.\(fresh.id)",
                module: .decisions,
                urgency: .settled,
                title: fresh.selectedOption ?? fresh.title,
                detail: copy.signalSettledDetail,
                symbol: "checkmark.seal.fill",
                at: fresh.resolvedAt ?? fresh.createdAt,
                target: .decision(id: fresh.id),
                worldCaption: nil
            ))
        }

        return ModuleContribution(
            signals: signals,
            summary: summary(copy, partnerName)
        )
    }

    private func summary(_ copy: Strings.Decisions, _ partnerName: String?) -> ModuleSummary {
        let status: String
        if case .error = phase {
            status = copy.statusReconnect
        } else if !needsMyResponse.isEmpty {
            status = copy.statusForYou(needsMyResponse.count)
        } else if !waitingForPartner.isEmpty {
            status = copy.statusWithPartner(waitingForPartner.count, partnerName)
        } else if decisions.isEmpty {
            status = copy.statusNothingOpen
        } else {
            status = copy.statusAllSettled
        }

        return ModuleSummary(
            module: .decisions,
            status: status,
            attention: needsMyResponse.count,
            isLive: false,
            target: .decisions
        )
    }
}
