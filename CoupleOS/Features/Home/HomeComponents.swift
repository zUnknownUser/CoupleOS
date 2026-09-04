import SwiftUI

struct CoupleHeader: View {
    let currentUser: User
    let partner: HomeFeature.PartnerState
    let isSigningOut: Bool
    let signOut: () -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        HStack(spacing: CoupleTheme.Space.medium) {
            HStack(spacing: -8) {
                PresenceMonogram(name: currentUser.firstName, color: CoupleTheme.ColorToken.mint)
                    .zIndex(1)
                partnerPresence
            }

            VStack(alignment: .leading, spacing: CoupleTheme.Space.xSmall) {
                Text(headerTitle)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    .lineLimit(1)
                Label(strings.home.privateSpace, systemImage: "lock.fill")
                    .font(CoupleTheme.TypeToken.caption)
                    .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                    // Truncating reads better here than a caption that grows
                    // to four lines and pushes the Home down with it.
                    .lineLimit(1)
            }

            Spacer(minLength: CoupleTheme.Space.small)

            CircularGlassButton(
                systemImage: "rectangle.portrait.and.arrow.right",
                action: signOut
            )
            .disabled(isSigningOut)
            .accessibilityLabel(strings.home.signOut)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var partnerPresence: some View {
        switch partner {
        case let .loaded(user):
            PresenceMonogram(name: user.firstName, color: CoupleTheme.ColorToken.amber)
        case .loading:
            PresenceMonogram(name: nil, color: CoupleTheme.ColorToken.amber)
                .redacted(reason: .placeholder)
        case .unavailable, .error:
            PresenceMonogram(name: nil, color: CoupleTheme.ColorToken.amber)
        }
    }

    private var headerTitle: String {
        guard case let .loaded(user) = partner else { return currentUser.firstName }
        return strings.home.bothNames(currentUser.firstName, user.firstName)
    }
}

private struct PresenceMonogram: View {
    let name: String?
    let color: Color

    @Environment(\.strings) private var strings

    var body: some View {
        ZStack {
            Circle().fill(CoupleTheme.ColorToken.worldCore)
            Circle().stroke(color.opacity(0.72), lineWidth: 1)
            Text(initial)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
        }
        .frame(width: 42, height: 42)
        .background(color.opacity(0.16), in: .circle)
        .accessibilityLabel(name ?? strings.home.partnerLoading)
    }

    private var initial: String {
        name?.trimmingCharacters(in: .whitespacesAndNewlines).first.map {
            String($0).uppercased()
        } ?? "·"
    }
}

struct PartnerRecovery: View {
    let error: UserClientError
    let retry: () -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        VStack(spacing: CoupleTheme.Space.small) {
            InlineMessage(text: strings.errors.user(error), style: .error)
            Button(strings.home.retryPartner, action: retry)
                .font(CoupleTheme.TypeToken.caption)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
        }
    }
}

struct HomeLoadingView: View {
    let firstName: String

    @Environment(\.strings) private var strings

    var body: some View {
        VStack(spacing: CoupleTheme.Space.large) {
            Text(strings.home.welcomeBack(firstName))
                .font(.system(.title, weight: .medium))
                .tracking(CoupleTheme.TypeToken.displayTracking)
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
            Text(strings.home.openingSharedWorld)
                .font(CoupleTheme.TypeToken.body)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct HomeErrorView: View {
    let error: CoupleClientError
    let retry: () -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        VStack(spacing: CoupleTheme.Space.large) {
            Text(strings.home.worldStillHere)
                .font(.system(.title, weight: .medium))
                .tracking(CoupleTheme.TypeToken.displayTracking)
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
                .multilineTextAlignment(.center)
            InlineMessage(text: strings.errors.couple(error), style: .error)
            PrimaryButton(title: strings.common.tryAgain, action: retry)
        }
        .frame(maxWidth: CoupleTheme.Size.panel)
    }
}
