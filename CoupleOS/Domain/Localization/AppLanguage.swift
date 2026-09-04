import Foundation

/// A language CoupleOS speaks.
///
/// Deliberately a closed set rather than a wrapper around `Locale`. Every
/// string in the app is written by hand in each of these, so a language the
/// catalogue cannot answer for is a language the app does not have — and
/// pretending otherwise would ship half-translated screens.
nonisolated enum AppLanguage: String, CaseIterable, Equatable, Hashable, Sendable {
    case english = "en"
    case portugueseBrazil = "pt-BR"

    /// The language named in itself. A person looking for their own language in
    /// a list is looking for the word they would use, not our word for it.
    var endonym: String {
        switch self {
        case .english: "English"
        case .portugueseBrazil: "Português"
        }
    }

    /// Two letters, for the one control discreet enough to live in a header.
    var shortCode: String {
        switch self {
        case .english: "EN"
        case .portugueseBrazil: "PT"
        }
    }

    /// The BCP 47 tag this language is delivered as — including to the backend,
    /// which picks push copy by it.
    var tag: String { rawValue }

    /// The closest language we speak to a BCP 47 identifier.
    ///
    /// Matching is on the primary subtag alone: someone whose phone is set to
    /// `pt-PT` is far better served by Brazilian Portuguese than by English,
    /// and the same holds for every English region.
    static func matching(_ identifier: String) -> AppLanguage? {
        let primary = identifier
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .first?
            .lowercased()

        switch primary {
        case "pt": return .portugueseBrazil
        case "en": return .english
        default: return nil
        }
    }

    /// The first language in the phone's ordered preferences that we speak.
    ///
    /// The order matters: iOS hands back every language the person has added,
    /// most-wanted first, so honouring the order is what makes a bilingual
    /// phone land where its owner expects.
    static func resolved(
        fromPreferred identifiers: [String],
        fallback: AppLanguage = .english
    ) -> AppLanguage {
        for identifier in identifiers {
            if let match = matching(identifier) { return match }
        }
        return fallback
    }
}
