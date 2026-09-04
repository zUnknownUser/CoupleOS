import SwiftUI

/// The manual override, kept as quiet as a control can be.
///
/// Two letters in tertiary text — no icon, no chevron, no label. It reads as
/// punctuation until someone is looking for it, which is the whole brief: the
/// app should already be in the right language, so this exists for the person
/// it guessed wrong about and for nobody else. It still carries a full 44pt
/// target and a spoken label, because discreet is a visual property and must
/// not quietly become an accessibility one.
struct LanguageControl: View {
    @Environment(\.strings) private var strings
    @Environment(\.languageSettings) private var settings

    var body: some View {
        Menu {
            Section(strings.languageMenu.title) {
                ForEach(settings.options, id: \.self) { option in
                    Button {
                        settings.select(option)
                    } label: {
                        Label {
                            Text(title(for: option))
                        } icon: {
                            if option == settings.preference { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
        } label: {
            Text(settings.resolved.shortCode)
                .font(CoupleTheme.TypeToken.caption)
                .tracking(1.2)
                .foregroundStyle(CoupleTheme.ColorToken.tertiaryText)
                .frame(
                    minWidth: CoupleTheme.Size.minimumTouchTarget,
                    minHeight: CoupleTheme.Size.minimumTouchTarget
                )
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(strings.languageMenu.accessibilityLabel(settings.resolved))
    }

    private func title(for option: LanguagePreference) -> String {
        switch option {
        case .automatic: strings.languageMenu.automatic(settings.systemLanguage)
        case let .fixed(language): language.endonym
        }
    }
}
