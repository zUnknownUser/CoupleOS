import ComposableArchitecture
import SwiftUI

struct SessionResolutionPanel: View {
    let store: StoreOf<SessionResolutionFeature>
    var body: some View {
        VStack(spacing: CoupleTheme.Space.medium) {
            Text(store.errorMessage == nil ? "Opening your world…" : "Your world is still here.")
                .font(CoupleTheme.TypeToken.body)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
            if let errorMessage = store.errorMessage {
                InlineMessage(text: errorMessage, style: .error)
                PrimaryButton(title: "Try again") { store.send(.retryTapped) }
            }
        }
        .frame(maxWidth: CoupleTheme.Size.panel)
    }
}

struct ProfileProvisioningPanel: View {
    let store: StoreOf<ProfileProvisioningFeature>
    var body: some View {
        VStack(spacing: CoupleTheme.Space.medium) {
            Text(store.errorMessage == nil ? "Finishing your space…" : "Your account is safe.")
                .font(CoupleTheme.TypeToken.body)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
            if let errorMessage = store.errorMessage {
                InlineMessage(text: errorMessage, style: .error)
                PrimaryButton(title: "Try again") { store.send(.retryTapped) }
            }
        }
        .frame(maxWidth: CoupleTheme.Size.panel)
    }
}

struct LoginPanel: View {
    @Bindable var store: StoreOf<LoginFeature>
    var body: some View {
        FormPanel(title: "Welcome back", subtitle: "Your world has been waiting.", backAction: {
            store.send(.backTapped)
        }) {
            CoupleInputGroup {
                CoupleInlineField(label: "EMAIL") {
                    TextField("you@example.com", text: $store.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(store.isLoading)
                }
                if let error = store.emailError { FieldMessage(text: error) }
                CoupleDivider()
                PasswordField(password: $store.password, isVisible: store.isPasswordVisible,
                    isEnabled: !store.isLoading, contentType: .password,
                    toggle: { store.send(.passwordVisibilityTapped) })
                if let error = store.passwordError { FieldMessage(text: error) }
            }
            Button("Forgot password?") { store.send(.forgotPasswordTapped) }
                .font(CoupleTheme.TypeToken.caption)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
                .disabled(store.isLoading)
            if let message = store.errorMessage { InlineMessage(text: message, style: .error) }
            if let message = store.confirmationMessage { InlineMessage(text: message, style: .success) }
            PrimaryButton(title: "Continue", isEnabled: !store.isLoading, isLoading: store.isLoading) {
                store.send(.continueTapped)
            }
            OrDivider()
            AppleSignInControl { store.send(.appleSignInTapped) }
                .frame(height: CoupleTheme.Size.buttonHeight)
                .clipShape(.capsule)
                .disabled(store.isLoading)
                .opacity(store.isLoading ? CoupleTheme.Opacity.disabled : 1)
        }
    }
}

struct CreateAccountPanel: View {
    @Bindable var store: StoreOf<SignUpFeature>
    var body: some View {
        FormPanel(title: "Create your account", subtitle: "A quiet key to the world you're about to make.",
            backAction: { store.send(.backTapped) }) {
            CoupleInputGroup {
                CoupleInlineField(label: "EMAIL") {
                    TextField("you@example.com", text: $store.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(store.isLoading)
                }
                if let error = store.emailError { FieldMessage(text: error) }
                CoupleDivider()
                PasswordField(password: $store.password, isVisible: store.isPasswordVisible,
                    isEnabled: !store.isLoading,
                    contentType: .newPassword, toggle: { store.send(.passwordVisibilityTapped) })
                if let error = store.passwordError { FieldMessage(text: error) }
            }
            if let message = store.errorMessage { InlineMessage(text: message, style: .error) }
            PrimaryButton(title: "Create account", isEnabled: !store.isLoading, isLoading: store.isLoading) {
                store.send(.createAccountTapped)
            }
            PrivacyNote(text: "Your account is personal. Your shared world belongs to both of you.")
        }
    }
}
