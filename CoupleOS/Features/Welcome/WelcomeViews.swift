import ComposableArchitecture
import SwiftUI

struct WelcomeHero: View {
    let store: StoreOf<WelcomeFeature>

    @Environment(\.strings) private var strings
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize = CoupleTheme.TypeToken.heroSize

    var body: some View {
        VStack(spacing: CoupleTheme.Space.large) {
            VStack(spacing: CoupleTheme.Space.medium) {
                Text(strings.welcome.heroTitle)
                    .font(.system(size: heroSize, weight: .medium))
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    .multilineTextAlignment(.center)
                    .tracking(-1.35)
                    .minimumScaleFactor(0.82)
                    .accessibilityAddTraits(.isHeader)
                Text(strings.welcome.heroSubtitle)
                    .font(CoupleTheme.TypeToken.body)
                    .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: CoupleTheme.Size.panel)
            }
            VStack(spacing: CoupleTheme.Space.small) {
                PrimaryButton(title: strings.welcome.createWorld) { store.send(.createWorldTapped) }
                GlassButton { store.send(.loginTapped) } label: {
                    Text(strings.welcome.haveAccount)
                        .font(CoupleTheme.TypeToken.button)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                        .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
                        .padding(.horizontal, CoupleTheme.Space.medium)
                }
                Button(strings.welcome.haveInvite) { store.send(.inviteTapped) }
                    .font(CoupleTheme.TypeToken.caption)
                    .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                    .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
            }
        }
    }
}

struct InvitePanel: View {
    @Bindable var store: StoreOf<InviteFeature>

    @Environment(\.strings) private var strings

    var body: some View {
        switch store.presentation {
        case .manualEntry:
            FormPanel(
                title: strings.invite.manualTitle,
                subtitle: strings.invite.manualSubtitle,
                backAction: { store.send(.backTapped) }
            ) {
                CoupleField(label: strings.invite.linkLabel) {
                    TextField(strings.invite.linkPlaceholder, text: $store.inviteCode)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if let error = store.error {
                    InlineMessage(text: strings.errors.invite(error), style: .error)
                }
                PrimaryButton(
                    title: strings.common.continueAction,
                    isEnabled: !store.inviteCode.isEmpty
                ) {
                    store.send(.continueTapped)
                }
                PrivacyNote(text: strings.invite.manualPrivacy)
            }
        case .invitation:
            FormPanel(
                title: strings.invite.invitationTitle,
                subtitle: strings.invite.invitationSubtitle,
                backAction: { store.send(.backTapped) }
            ) {
                PrimaryButton(title: strings.invite.joinTheirWorld) { store.send(.joinTapped) }
                PrivacyNote(text: strings.invite.invitationPrivacy)
            }
        case .accountChoice:
            FormPanel(
                title: strings.invite.choiceTitle,
                subtitle: strings.invite.choiceSubtitle,
                backAction: { store.send(.backTapped) }
            ) {
                PrimaryButton(title: strings.invite.createAccount) {
                    store.send(.createAccountTapped)
                }
                GlassButton { store.send(.signInTapped) } label: {
                    Text(strings.invite.signIn)
                        .font(CoupleTheme.TypeToken.button)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                        .frame(maxWidth: .infinity, minHeight: CoupleTheme.Size.minimumTouchTarget)
                }
            }
        }
    }
}
