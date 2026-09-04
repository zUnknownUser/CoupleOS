import ComposableArchitecture
import SwiftUI

struct IdentityPanel: View {
    @Bindable var store: StoreOf<IdentityFeature>
    var body: some View {
        FormPanel(title: "Let's start with you.",
            subtitle: "One person begins. The world becomes yours when the other arrives.",
            backAction: { store.send(.backTapped) }) {
            CoupleField(label: "YOUR NAME") {
                TextField("What should we call you?", text: $store.firstName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
            }
            if let error = store.nameError { FieldMessage(text: error) }
            PrimaryButton(title: "Continue") { store.send(.continueTapped) }
            PrivacyNote(text: "Private by design. Nothing here is public.")
        }
    }
}

struct ProfileRecoveryPanel: View {
    @Bindable var store: StoreOf<ProfileRecoveryFeature>
    var body: some View {
        FormPanel(title: "Let's finish your space.",
            subtitle: "Your account is safe. We just need the name that belongs inside your world.",
            backAction: nil) {
            CoupleField(label: "YOUR NAME") {
                TextField("What should we call you?", text: $store.firstName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .disabled(store.isLoading)
            }
            if let error = store.nameError { FieldMessage(text: error) }
            if let message = store.errorMessage { InlineMessage(text: message, style: .error) }
            PrimaryButton(title: "Continue", isEnabled: !store.isLoading, isLoading: store.isLoading) {
                store.send(.continueTapped)
            }
            PrivacyNote(text: "We found your account and will continue exactly where you left off.")
        }
    }
}
