import ComposableArchitecture
import SwiftUI

struct WelcomeHero: View {
    let store: StoreOf<WelcomeFeature>
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize = CoupleTheme.TypeToken.heroSize
    var body: some View {
        VStack(spacing: CoupleTheme.Space.large) {
            VStack(spacing: CoupleTheme.Space.medium) {
                Text("Your world.\nJust the two of you.")
                    .font(.system(size: heroSize, weight: .medium))
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    .multilineTextAlignment(.center)
                    .tracking(-1.35)
                    .minimumScaleFactor(0.82)
                    .accessibilityAddTraits(.isHeader)
                Text("A private space to stay close, share life and build something that's only yours.")
                    .font(CoupleTheme.TypeToken.body)
                    .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: CoupleTheme.Size.panel)
            }
            VStack(spacing: CoupleTheme.Space.small) {
                PrimaryButton(title: "Create our world") { store.send(.createWorldTapped) }
                GlassButton { store.send(.loginTapped) } label: {
                    Text("I already have an account")
                        .font(CoupleTheme.TypeToken.button)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                        .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
                        .padding(.horizontal, CoupleTheme.Space.medium)
                }
                Button("I have an invite") { store.send(.inviteTapped) }
                    .font(CoupleTheme.TypeToken.caption)
                    .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                    .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
            }
        }
    }
}

struct InvitePanel: View {
    @Bindable var store: StoreOf<InviteFeature>
    var body: some View {
        switch store.presentation {
        case .manualEntry:
            FormPanel(title: "Step into your world.", subtitle: "Use the private invite your person shared with you.",
                backAction: { store.send(.backTapped) }) {
                CoupleField(label: "INVITE LINK") {
                    TextField("Paste your private link", text: $store.inviteCode)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if let message = store.errorMessage { InlineMessage(text: message, style: .error) }
                PrimaryButton(title: "Continue", isEnabled: !store.inviteCode.isEmpty) {
                    store.send(.continueTapped)
                }
                PrivacyNote(text: "The link reveals no private information before you sign in.")
            }
        case .invitation:
            FormPanel(
                title: "You’ve been invited into someone’s world.",
                subtitle: "A private Couple OS space is waiting for both of you.",
                backAction: { store.send(.backTapped) }
            ) {
                PrimaryButton(title: "Join their world") { store.send(.joinTapped) }
                PrivacyNote(text: "You'll see who invited you only after your account is verified.")
            }
        case .accountChoice:
            FormPanel(
                title: "How would you like to enter?",
                subtitle: "Your invite will stay with you through sign in.",
                backAction: { store.send(.backTapped) }
            ) {
                PrimaryButton(title: "Create account") { store.send(.createAccountTapped) }
                GlassButton { store.send(.signInTapped) } label: {
                    Text("Sign in")
                        .font(CoupleTheme.TypeToken.button)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                        .frame(maxWidth: .infinity, minHeight: CoupleTheme.Size.minimumTouchTarget)
                }
            }
        }
    }
}
