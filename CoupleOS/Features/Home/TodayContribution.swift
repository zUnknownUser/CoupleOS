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
    func homeContribution(partnerName: String?) -> ModuleContribution {
        let person = partnerName ?? "Your person"
        var signals: [HomeSignal] = []

        if dailyErrorMessage == nil, let experience = dailyExperience, let status = dailyStatus {
            signals.append(HomeSignal(
                id: "today.\(experience.id)",
                module: .today,
                urgency: status.urgency,
                title: experience.prompt,
                detail: status.detail(person: person),
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
                status: statusLine(person: person),
                attention: dailyStatus == .waitingForMe || dailyStatus == .available ? 1 : 0,
                isLive: false,
                target: .today
            )
        )
    }

    private func statusLine(person: String) -> String {
        guard dailyErrorMessage == nil else { return "Tap to reconnect" }
        switch dailyStatus {
        case .available: return "Open for both"
        case .waitingForMe: return "Waiting for you"
        case .waitingForPartner: return "Waiting for \(person)"
        case .revealAvailable: return "Revealed"
        case nil: return "Opening…"
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

    func detail(person: String) -> String {
        switch self {
        case .available: "A small choice for each of you"
        case .waitingForMe: "\(person) left something here"
        case .waitingForPartner: "Your answer is in — waiting for \(person)"
        case .revealAvailable: "You both answered — see what it means"
        }
    }
}
