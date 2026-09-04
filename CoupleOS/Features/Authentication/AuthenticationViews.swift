import ComposableArchitecture
import SwiftUI

struct SessionResolutionPanel: View {
    let store: StoreOf<SessionResolutionFeature>

    @Environment(\.strings) private var strings

    var body: some View {
        VStack(spacing: CoupleTheme.Space.medium) {
            Text(store.error == nil
                ? strings.session.openingYourWorld
                : strings.session.worldStillHere)
                .font(CoupleTheme.TypeToken.body)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
            if let error = store.error {
                InlineMessage(text: strings.errors.user(error), style: .error)
                PrimaryButton(title: strings.common.tryAgain) { store.send(.retryTapped) }
            }
        }
        .frame(maxWidth: CoupleTheme.Size.panel)
    }
}

struct ProfileProvisioningPanel: View {
    let store: StoreOf<ProfileProvisioningFeature>

    @Environment(\.strings) private var strings

    var body: some View {
        VStack(spacing: CoupleTheme.Space.medium) {
            Text(store.error == nil
                ? strings.session.finishingYourSpace
                : strings.session.accountSafe)
                .font(CoupleTheme.TypeToken.body)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
            if let error = store.error {
                InlineMessage(text: strings.errors.user(error), style: .error)
                PrimaryButton(title: strings.common.tryAgain) { store.send(.retryTapped) }
            }
        }
        .frame(maxWidth: CoupleTheme.Size.panel)
    }
}

struct LoginPanel: View {
    @Bindable var store: StoreOf<LoginFeature>

    @Environment(\.strings) private var strings

    var body: some View {
        FormPanel(
            title: strings.auth.loginTitle,
            subtitle: strings.auth.loginSubtitle,
            backAction: { store.send(.backTapped) }
        ) {
            CoupleInputGroup {
                CoupleInlineField(label: strings.auth.emailLabel) {
                    TextField(strings.auth.emailPlaceholder, text: $store.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(store.isLoading)
                }
                if let error = store.emailError {
                    FieldMessage(text: strings.auth.validation(error))
                }
                CoupleDivider()
                PasswordField(password: $store.password, isVisible: store.isPasswordVisible,
                    isEnabled: !store.isLoading, contentType: .password,
                    toggle: { store.send(.passwordVisibilityTapped) })
                if let error = store.passwordError {
                    FieldMessage(text: strings.auth.validation(error))
                }
            }
            Button(strings.auth.forgotPassword) { store.send(.forgotPasswordTapped) }
                .font(CoupleTheme.TypeToken.caption)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
                .disabled(store.isLoading)
            if let error = store.error {
                InlineMessage(text: strings.errors.authentication(error), style: .error)
            }
            if store.passwordResetSent {
                InlineMessage(text: strings.auth.resetLinkSent, style: .success)
            }
            PrimaryButton(
                title: strings.common.continueAction,
                isEnabled: !store.isLoading,
                isLoading: store.isLoading
            ) {
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

    @Environment(\.strings) private var strings

    var body: some View {
        FormPanel(
            title: strings.auth.signUpTitle,
            subtitle: strings.auth.signUpSubtitle,
            backAction: { store.send(.backTapped) }
        ) {
            CoupleInputGroup {
                CoupleInlineField(label: strings.auth.emailLabel) {
                    TextField(strings.auth.emailPlaceholder, text: $store.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(store.isLoading)
                }
                if let error = store.emailError {
                    FieldMessage(text: strings.auth.validation(error))
                }
                CoupleDivider()
                PasswordField(password: $store.password, isVisible: store.isPasswordVisible,
                    isEnabled: !store.isLoading,
                    contentType: .newPassword, toggle: { store.send(.passwordVisibilityTapped) })
                if let error = store.passwordError {
                    FieldMessage(text: strings.auth.validation(error))
                }
            }
            if let error = store.error {
                InlineMessage(text: strings.errors.authentication(error), style: .error)
            }
            PrimaryButton(
                title: strings.auth.createAccount,
                isEnabled: !store.isLoading,
                isLoading: store.isLoading
            ) {
                store.send(.createAccountTapped)
            }
            PrivacyNote(text: strings.auth.signUpPrivacy)
        }
    }
}
