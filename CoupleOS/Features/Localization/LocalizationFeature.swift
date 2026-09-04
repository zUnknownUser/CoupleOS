import ComposableArchitecture
import Foundation

/// Which language the app is speaking, and why.
///
/// A feature rather than a value on `AppFeature.State` because there are two
/// inputs to reconcile — the phone's setting and the couple's own choice — and
/// a delegate to announce when the answer changes, so anything downstream of
/// the language (today, only the push device record) can follow.
@Reducer
nonisolated struct LocalizationFeature {
    @ObservableState
    struct State: Equatable {
        var preference: LanguagePreference = .automatic
        /// Re-read on every `.task`, so a change made in iOS Settings while the
        /// app was backgrounded lands the next time it opens.
        var systemLanguage: AppLanguage = .english

        /// The language actually in use.
        var language: AppLanguage { preference.resolve(system: systemLanguage) }

        /// What the discreet control offers, always in this order: automatic
        /// first, because it is the answer most people want and the one they
        /// can get back to.
        var options: [LanguagePreference] {
            [.automatic] + AppLanguage.allCases.map(LanguagePreference.fixed)
        }
    }

    enum Action: Equatable {
        case task
        case preferenceSelected(LanguagePreference)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case languageChanged(AppLanguage)
        }
    }

    @Dependency(\.localizationClient) var localizationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let previous = state.language
                state.systemLanguage = localizationClient.systemLanguage()
                state.preference = localizationClient.loadPreference()
                return announce(state.language, ifChangedFrom: previous)

            case let .preferenceSelected(preference):
                guard state.preference != preference else { return .none }
                let previous = state.language
                state.preference = preference
                let language = state.language
                return .merge(
                    .run { _ in localizationClient.savePreference(preference) },
                    announce(language, ifChangedFrom: previous)
                )

            case .delegate:
                return .none
            }
        }
    }

    /// Silent when the resolved language did not move. Choosing "English"
    /// explicitly while the phone was already English changes what is stored,
    /// but nothing downstream needs to hear about it.
    private func announce(
        _ language: AppLanguage,
        ifChangedFrom previous: AppLanguage
    ) -> Effect<Action> {
        guard language != previous else { return .none }
        return .send(.delegate(.languageChanged(language)))
    }
}
