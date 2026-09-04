import ComposableArchitecture
import SwiftUI

struct ReadyForPartnerPanel: View {
    let store: StoreOf<ReadyForPartnerFeature>
    @State private var copied = false

    var body: some View {
        VStack(spacing: CoupleTheme.Space.large) {
            switch store.phase {
            case .preparingWorld, .readyToInvite:
                VStack(spacing: CoupleTheme.Space.small) {
                    Text("Preparing your world…")
                        .font(.system(.title, weight: .medium))
                        .tracking(CoupleTheme.TypeToken.displayTracking)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    Text("A private space is taking shape.")
                        .font(CoupleTheme.TypeToken.body)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                }
            case let .waitingForPartner(_, invite):
                VStack(spacing: CoupleTheme.Space.large) {
                    VStack(spacing: CoupleTheme.Space.small) {
                        Text("Waiting for your person.")
                            .font(.system(.title, weight: .medium))
                            .tracking(CoupleTheme.TypeToken.displayTracking)
                            .foregroundStyle(CoupleTheme.ColorToken.pearl)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text("Your world changes when they arrive.")
                            .font(CoupleTheme.TypeToken.body)
                            .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: CoupleTheme.Space.small) {
                        ShareLink(
                            item: invite.url,
                            subject: Text("A private Couple OS invite"),
                            message: Text("Join me in our private Couple World.")
                        ) {
                            Text("Share invite")
                                .font(CoupleTheme.TypeToken.button)
                                .frame(maxWidth: .infinity, minHeight: CoupleTheme.Size.buttonHeight)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(CoupleTheme.ColorToken.accent.opacity(0.94))
                        .foregroundStyle(CoupleTheme.ColorToken.space)
                        Button(copied ? "Link copied" : "Copy link") {
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
                    Text("Your world is now shared.")
                        .font(.system(.title, weight: .medium))
                        .tracking(CoupleTheme.TypeToken.displayTracking)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("Two presences. One private place.")
                        .font(CoupleTheme.TypeToken.body)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                }
            case let .error(message):
                VStack(spacing: CoupleTheme.Space.medium) {
                    Text("Your world is still here.")
                    .font(.system(.title, weight: .medium))
                    .tracking(CoupleTheme.TypeToken.displayTracking)
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    InlineMessage(text: message, style: .error)
                    PrimaryButton(title: "Try again") { store.send(.retryTapped) }
                }
            }
            if let message = store.signOutError { InlineMessage(text: message, style: .error) }
            Button("Sign out") { store.send(.signOutTapped) }
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

    var body: some View {
        VStack(spacing: CoupleTheme.Space.large) {
            switch store.phase {
            case .accepting:
                VStack(spacing: CoupleTheme.Space.small) {
                    Text("Joining your world…")
                        .font(.system(.title, weight: .medium))
                        .tracking(CoupleTheme.TypeToken.displayTracking)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    Text("Connecting both of you securely.")
                        .font(CoupleTheme.TypeToken.body)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                }
            case .joined:
                VStack(spacing: CoupleTheme.Space.small) {
                    Text("Your world is now shared.")
                        .font(.system(.title, weight: .medium))
                        .tracking(CoupleTheme.TypeToken.displayTracking)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("This private place belongs to both of you.")
                        .font(CoupleTheme.TypeToken.body)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                        .multilineTextAlignment(.center)
                }
            case let .error(message):
                VStack(spacing: CoupleTheme.Space.medium) {
                    Text("We couldn't join this world.")
                        .font(.system(.title, weight: .medium))
                        .tracking(CoupleTheme.TypeToken.displayTracking)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    InlineMessage(text: message, style: .error)
                    PrimaryButton(title: "Try again") { store.send(.retryTapped) }
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
