import Foundation

/// Every area of the couple's shared life that can speak on the Home.
///
/// The case carries identity and a symbol only. Its name is a word, so it
/// lives in `Strings` and is read through `strings.home.moduleTitle(_:)` —
/// which is what lets a module be called "Market" or "Mercado" without this
/// type knowing either.
///
/// This is the list the Home grows by. A new area becomes visible in three
/// steps: add a case here, teach its feature to build a `ModuleContribution`,
/// and hand that contribution to `HomeComposition`. The Home surface itself
/// never learns what a Market or a Decision is — it only merges and orders.
nonisolated enum CoupleModule: String, CaseIterable, Identifiable, Sendable {
    case market
    case chores
    case decisions
    case today

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .market: "basket.fill"
        case .chores: "house.fill"
        case .decisions: "arrow.triangle.branch"
        case .today: "sparkle"
        }
    }
}

/// One thing asking for the couple's attention, told in a shape the Home can
/// render without knowing which area it came from.
nonisolated struct HomeSignal: Equatable, Identifiable, Sendable {
    /// How loudly a signal asks. This order *is* the order of the Home.
    nonisolated enum Urgency: Int, Comparable, Sendable {
        /// Happening right now, on the other side of the city. Perishable in a
        /// way nothing else is: a person standing in an aisle cannot wait.
        case live
        case needsYou
        case needsBoth
        case waiting
        /// Just became true together. Present only while it is still warm.
        case settled

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// Where a signal leads. One case per destination the Home can open, which
    /// is what keeps `AuthenticatedFeature` the single place that routes.
    nonisolated enum Target: Equatable, Hashable, Sendable {
        case today
        case decisions
        case decision(id: String)
        case market
        case chores
    }

    let id: String
    let module: CoupleModule
    let urgency: Urgency
    let title: String
    let detail: String
    let symbol: String
    let at: Date
    let target: Target
    /// What the world should say while this signal is the loudest one. A module
    /// speaks for the world in its own voice; `nil` accepts the shared line.
    var worldCaption: String?
}

/// An area as it appears in the couple's map of itself — always present, even
/// when it has nothing urgent to say.
nonisolated struct ModuleSummary: Equatable, Identifiable, Sendable {
    let module: CoupleModule
    let status: String
    var attention: Int = 0
    var isLive: Bool = false
    let target: HomeSignal.Target

    var id: String { module.id }
}

/// What one area hands to the Home: whatever is urgent now, and how the area
/// describes itself at rest.
nonisolated struct ModuleContribution: Equatable, Sendable {
    var signals: [HomeSignal] = []
    var summary: ModuleSummary
}

/// The Home surface, merged from every area that had something to say.
///
/// Nothing here is module-specific on purpose. Ordering, the world's mood and
/// its caption all fall out of the signals themselves, so an area added next
/// year lands in the right place without this type being touched.
nonisolated struct HomeComposition: Equatable, Sendable {
    let signals: [HomeSignal]
    let areas: [ModuleSummary]

    init(_ contributions: [ModuleContribution]) {
        signals = contributions
            .flatMap(\.signals)
            .sorted { first, second in
                first.urgency == second.urgency
                    ? first.at > second.at
                    : first.urgency < second.urgency
            }
        areas = contributions.map(\.summary)
    }

    /// The loudest thing in the couple's life right now, if anything is loud.
    var leading: HomeSignal? { signals.first }

    var isQuiet: Bool { signals.isEmpty }

    /// How much of the couple's life is currently unattended. Drives nothing
    /// visual on its own — it exists so a badge never has to count by hand.
    var attention: Int {
        signals.filter { $0.urgency == .needsYou || $0.urgency == .live }.count
    }
}

nonisolated enum CoupleTiming {
    /// How long something stays worth mentioning on the Home after it becomes
    /// true. Past this, it belongs to the couple's history, not their present.
    static let freshWindow: TimeInterval = 24 * 60 * 60

    /// How long something can sit unattended before it stops describing now.
    ///
    /// Past this it is not deleted — losing what someone asked for is the exact
    /// failure this app exists to prevent — but it stops competing for
    /// attention with things that are actually current.
    static let staleWindow: TimeInterval = 14 * 24 * 60 * 60
}
