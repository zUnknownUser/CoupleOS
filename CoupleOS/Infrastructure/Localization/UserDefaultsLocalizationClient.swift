import Foundation

/// The only place that knows language preference is stored on disk at all.
///
/// `UserDefaults` rather than Firestore on purpose: this is a property of the
/// phone in someone's hand, not of the couple. Two people in one Couple World
/// can read it in different languages, and a signed-out phone still opens in
/// the language its owner chose.
extension LocalizationClient {
    static let userDefaults = Self(
        systemLanguage: {
            AppLanguage.resolved(fromPreferred: Locale.preferredLanguages)
        },
        loadPreference: {
            guard let stored = UserDefaults.standard.string(forKey: DefaultsKey.preference) else {
                return .automatic
            }
            return LanguagePreference(storedValue: stored)
        },
        savePreference: { preference in
            UserDefaults.standard.set(preference.storedValue, forKey: DefaultsKey.preference)
        }
    )
}

private enum DefaultsKey {
    static let preference = "com.coupleos.languagePreference"
}
