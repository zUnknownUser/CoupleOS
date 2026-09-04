import SwiftUI

extension EnvironmentValues {
    /// The catalogue every view reads its words from.
    ///
    /// Injected once, at the root, from the language the app resolved. A view
    /// that needs a word takes it from here rather than holding a literal, so
    /// changing the language redraws the app in it — no relaunch, no bundle
    /// swap. The default is English so previews and isolated views still read.
    @Entry var strings: Strings = .english

    /// What the discreet override needs to do its job.
    ///
    /// In the environment rather than passed down because the control appears
    /// in two places on opposite sides of the sign-in boundary — the shell
    /// before there is a couple, the Home header after — and threading a store
    /// through both would put language plumbing in every view between.
    @Entry var languageSettings = LanguageSettings()
}

/// The language choice, as much of it as a control needs.
struct LanguageSettings {
    var preference: LanguagePreference = .automatic
    var systemLanguage: AppLanguage = .english
    var options: [LanguagePreference] = [.automatic]
        + AppLanguage.allCases.map(LanguagePreference.fixed)
    var select: (LanguagePreference) -> Void = { _ in }

    var resolved: AppLanguage { preference.resolve(system: systemLanguage) }
}
