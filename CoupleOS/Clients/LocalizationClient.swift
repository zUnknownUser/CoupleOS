import ComposableArchitecture
import Foundation

/// The port between the app and everything outside it that has an opinion
/// about language: the phone's own settings, and the one place the couple's
/// manual choice is remembered.
///
/// Nothing here returns copy. Resolving *which* language is a side effect —
/// it reads the system and the disk — while the words themselves are a pure
/// value (`Strings`) the presentation layer picks with the answer.
@DependencyClient
nonisolated struct LocalizationClient: Sendable {
    /// What the phone asks for, re-read on every call so a change made in
    /// Settings is picked up without reinstalling.
    var systemLanguage: @Sendable () -> AppLanguage = { .english }

    var loadPreference: @Sendable () -> LanguagePreference = { .automatic }

    var savePreference: @Sendable (LanguagePreference) -> Void
}

extension LocalizationClient: DependencyKey {
    static let liveValue = LocalizationClient.userDefaults

    /// Language is ambient: every feature test resolves it on `.task` without
    /// being about it. English with no stored choice keeps those tests reading
    /// in the language their assertions are written in.
    static let testValue = LocalizationClient(
        systemLanguage: { .english },
        loadPreference: { .automatic },
        savePreference: { _ in }
    )
}

extension DependencyValues {
    nonisolated var localizationClient: LocalizationClient {
        get { self[LocalizationClient.self] }
        set { self[LocalizationClient.self] = newValue }
    }
}
