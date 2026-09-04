import Foundation

/// What the couple asked for, which is not the same as what they get.
///
/// `.automatic` is the default and stays a *preference*, not a snapshot: a
/// person who moves their phone to Portuguese should find the app already
/// there, and storing the resolved language instead would freeze the answer at
/// whatever the phone said the first time the app opened.
nonisolated enum LanguagePreference: Equatable, Hashable, Sendable {
    case automatic
    case fixed(AppLanguage)

    func resolve(system: AppLanguage) -> AppLanguage {
        switch self {
        case .automatic: system
        case let .fixed(language): language
        }
    }

    var chosenLanguage: AppLanguage? {
        guard case let .fixed(language) = self else { return nil }
        return language
    }

    // MARK: - Storage

    /// A single string, so the whole preference survives in one defaults key.
    var storedValue: String {
        switch self {
        case .automatic: Self.automaticToken
        case let .fixed(language): language.rawValue
        }
    }

    init(storedValue: String) {
        guard storedValue != Self.automaticToken,
              let language = AppLanguage(rawValue: storedValue) else {
            self = .automatic
            return
        }
        self = .fixed(language)
    }

    /// Not a valid language tag, so it can never collide with one.
    private static let automaticToken = "automatic"
}
