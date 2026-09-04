import ComposableArchitecture
import SwiftUI

struct IdentityPanel: View {
    @Bindable var store: StoreOf<IdentityFeature>

    @Environment(\.strings) private var strings

    var body: some View {
        FormPanel(
            title: strings.identity.title,
            subtitle: strings.identity.subtitle,
            backAction: { store.send(.backTapped) }
        ) {
            CoupleField(label: strings.identity.nameLabel) {
                TextField(strings.identity.namePlaceholder, text: $store.firstName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
            }
            if let error = store.nameError {
                FieldMessage(text: strings.auth.validation(error))
            }
            PrimaryButton(title: strings.common.continueAction) { store.send(.continueTapped) }
            PrivacyNote(text: strings.identity.privacy)
        }
    }
}

struct ProfileRecoveryPanel: View {
    @Bindable var store: StoreOf<ProfileRecoveryFeature>

    @Environment(\.strings) private var strings

    var body: some View {
        FormPanel(
            title: strings.identity.recoveryTitle,
            subtitle: strings.identity.recoverySubtitle,
            backAction: nil
        ) {
            CoupleField(label: strings.identity.nameLabel) {
                TextField(strings.identity.namePlaceholder, text: $store.firstName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .disabled(store.isLoading)
            }
            if let error = store.nameError {
                FieldMessage(text: strings.auth.validation(error))
            }
            if let error = store.error {
                InlineMessage(text: strings.errors.user(error), style: .error)
            }
            PrimaryButton(
                title: strings.common.continueAction,
                isEnabled: !store.isLoading,
                isLoading: store.isLoading
            ) {
                store.send(.continueTapped)
            }
            PrivacyNote(text: strings.identity.recoveryPrivacy)
        }
    }
}
