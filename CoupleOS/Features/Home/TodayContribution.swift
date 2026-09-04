import Foundation

extension HomeFeature.State {
    var partnerName: String? {
        guard case let .loaded(partner) = partner else { return nil }
        return partner.firstName
    }

    /// How Today speaks on the Home.
    ///
    /// Today is always exactly one thing, so it is always exactly one signal —
    /// what changes is how loudly it asks.
    ///
    /// The catalogue arrives as a parameter rather than being read from a
    /// dependency: a contribution is a pure function of state, the clock and
    /// the language, and keeping all three as arguments is what lets a test ask
    /// what the Home said in Portuguese last Tuesday.
    func homeContribution(strings: Strings, partnerName: String?) -> ModuleContribution {
        let copy = strings.today
        var signals: [HomeSignal] = []

        if dailyError == nil, let experience = dailyExperience, let status = dailyStatus {
            signals.append(HomeSignal(
                id: "today.\(experience.id)",
                module: .today,
                urgency: status.urgency,
                title: copy.prompt(experience),
                detail: status.detail(copy, partnerName),
                symbol: status.symbol,
                // Today outranks its peers within a tier: of everything at the
                // same urgency, it is the one that expires tonight.
                at: .distantFuture,
                target: .today,
                worldCaption: nil
            ))
        }

        return ModuleContribution(
            signals: signals,
            summary: ModuleSummary(
                module: .today,
                status: statusLine(copy, partnerName),
                attention: dailyStatus == .waitingForMe || dailyStatus == .available ? 1 : 0,
                isLive: false,
                target: .today
            )
        )
    }

    private func statusLine(_ copy: Strings.Today, _ partnerName: String?) -> String {
        guard dailyError == nil else { return copy.statusReconnect }
        switch dailyStatus {
        case .available: return copy.statusOpenForBoth
        case .waitingForMe: return copy.statusWaitingForYou
        case .waitingForPartner: return copy.statusWaitingForPartner(partnerName)
        case .revealAvailable: return copy.statusRevealed
        case nil: return copy.statusOpening
        }
    }
}

private extension DailyExperience.Status {
    var urgency: HomeSignal.Urgency {
        switch self {
        case .available: .needsBoth
        case .waitingForMe: .needsYou
        case .waitingForPartner: .waiting
        case .revealAvailable: .settled
        }
    }

    var symbol: String {
        switch self {
        case .available: "circle.grid.2x1.fill"
        case .waitingForMe: "sparkle"
        case .waitingForPartner: "ellipsis"
        case .revealAvailable: "sparkles"
        }
    }

    func detail(_ copy: Strings.Today, _ partnerName: String?) -> String {
        switch self {
        case .available: copy.detailAvailable
        case .waitingForMe: copy.detailWaitingForMe(partnerName)
        case .waitingForPartner: copy.detailWaitingForPartner(partnerName)
        case .revealAvailable: copy.detailRevealAvailable
        }
    }
}
