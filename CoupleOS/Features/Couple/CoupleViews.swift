import ComposableArchitecture
import SwiftUI

struct ReadyForPartnerPanel: View {
    let store: StoreOf<ReadyForPartnerFeature>

    @Environment(\.strings) private var strings
    @State private var copied = false

    var body: some View {
        VStack(spacing: CoupleTheme.Space.large) {
            switch store.phase {
            case .preparingWorld, .readyToInvite:
                VStack(spacing: CoupleTheme.Space.small) {
                    Text(strings.couple.preparingTitle)
                        .font(.system(.title, weight: .medium))
                        .tracking(CoupleTheme.TypeToken.displayTracking)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    Text(strings.couple.preparingSubtitle)
                        .font(CoupleTheme.TypeToken.body)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                }
            case let .waitingForPartner(_, invite):
                VStack(spacing: CoupleTheme.Space.large) {
                    VStack(spacing: CoupleTheme.Space.small) {
                        Text(strings.couple.waitingTitle)
                            .font(.system(.title, weight: .medium))
                            .tracking(CoupleTheme.TypeToken.displayTracking)
                            .foregroundStyle(CoupleTheme.ColorToken.pearl)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(strings.couple.waitingSubtitle)
                            .font(CoupleTheme.TypeToken.body)
                            .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: CoupleTheme.Space.small) {
                        ShareLink(
                            item: invite.url,
                            subject: Text(strings.couple.shareSubject),
                            message: Text(strings.couple.shareMessage)
                        ) {
                            Text(strings.couple.shareInvite)
                                .font(CoupleTheme.TypeToken.button)
                                .frame(maxWidth: .infinity, minHeight: CoupleTheme.Size.buttonHeight)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(CoupleTheme.ColorToken.accent.opacity(0.94))
                        .foregroundStyle(CoupleTheme.ColorToken.space)
                        Button(copied ? strings.couple.linkCopied : strings.couple.copyLink) {
                            UIPasteboard.general.url = invite.url
                            copied = true
                        }
                        .font(CoupleTheme.TypeToken.caption)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                        .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
                    }
                }
            case .partnerJoined:
                VStack(spacing: CoupleTheme.Space.small) {
                    Text(strings.couple.sharedTitle)
                        .font(.system(.title, weight: .medium))
                        .tracking(CoupleTheme.TypeToken.displayTracking)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(strings.couple.sharedSubtitle)
                        .font(CoupleTheme.TypeToken.body)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                }
            case let .error(error):
                VStack(spacing: CoupleTheme.Space.medium) {
                    Text(strings.couple.worldStillHere)
                    .font(.system(.title, weight: .medium))
                    .tracking(CoupleTheme.TypeToken.displayTracking)
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    InlineMessage(
                        text: strings.couple.preparationError(error, strings.errors),
                        style: .error
                    )
                    PrimaryButton(title: strings.common.tryAgain) { store.send(.retryTapped) }
                }
            }
            if let error = store.signOutError {
                InlineMessage(text: strings.errors.authentication(error), style: .error)
            }
            Button(strings.common.signOut) { store.send(.signOutTapped) }
                .font(CoupleTheme.TypeToken.caption)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
                .disabled(store.isSigningOut)
        }
        .frame(maxWidth: CoupleTheme.Size.panel)
        .task { await store.send(.task).finish() }
        .sensoryFeedback(.impact(weight: .light), trigger: isPartnerJoined)
    }

    private var isPartnerJoined: Bool {
        if case .partnerJoined = store.phase { return true }
        return false
    }
}

struct InviteAcceptancePanel: View {
    let store: StoreOf<InviteAcceptanceFeature>

    @Environment(\.strings) private var strings

    var body: some View {
        VStack(spacing: CoupleTheme.Space.large) {
            switch store.phase {
            case .accepting:
                VStack(spacing: CoupleTheme.Space.small) {
                    Text(strings.couple.joiningTitle)
                        .font(.system(.title, weight: .medium))
                        .tracking(CoupleTheme.TypeToken.displayTracking)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    Text(strings.couple.joiningSubtitle)
                        .font(CoupleTheme.TypeToken.body)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                }
            case .joined:
                VStack(spacing: CoupleTheme.Space.small) {
                    Text(strings.couple.sharedTitle)
                        .font(.system(.title, weight: .medium))
                        .tracking(CoupleTheme.TypeToken.displayTracking)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(strings.couple.joinedSubtitle)
                        .font(CoupleTheme.TypeToken.body)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                        .multilineTextAlignment(.center)
                }
            case let .error(error):
                VStack(spacing: CoupleTheme.Space.medium) {
                    Text(strings.couple.couldNotJoinTitle)
                        .font(.system(.title, weight: .medium))
                        .tracking(CoupleTheme.TypeToken.displayTracking)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    InlineMessage(text: strings.errors.invite(error), style: .error)
                    PrimaryButton(title: strings.common.tryAgain) { store.send(.retryTapped) }
                }
            }
        }
        .frame(maxWidth: CoupleTheme.Size.panel)
        .task { await store.send(.task).finish() }
        .sensoryFeedback(.impact(weight: .light), trigger: isJoined)
    }

    private var isJoined: Bool {
        if case .joined = store.phase { return true }
        return false
    }
}
