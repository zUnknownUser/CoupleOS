import SwiftUI

struct CoupleHeader: View {
    let currentUser: User
    let partner: HomeFeature.PartnerState
    let isSigningOut: Bool
    let signOut: () -> Void

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
                Label("Private shared space", systemImage: "lock.fill")
                    .font(CoupleTheme.TypeToken.caption)
                    .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
            }

            Spacer(minLength: CoupleTheme.Space.small)

            CircularGlassButton(
                systemImage: "rectangle.portrait.and.arrow.right",
                action: signOut
            )
            .disabled(isSigningOut)
            .accessibilityLabel("Sign out")
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
        return "\(currentUser.firstName) & \(user.firstName)"
    }
}

private struct PresenceMonogram: View {
    let name: String?
    let color: Color

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
        .accessibilityLabel(name ?? "Partner profile loading")
    }

    private var initial: String {
        name?.trimmingCharacters(in: .whitespacesAndNewlines).first.map {
            String($0).uppercased()
        } ?? "·"
    }
}

struct PartnerRecovery: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: CoupleTheme.Space.small) {
            InlineMessage(text: message, style: .error)
            Button("Try partner profile again", action: retry)
                .font(CoupleTheme.TypeToken.caption)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
        }
    }
}

struct HomeLoadingView: View {
    let firstName: String

    var body: some View {
        VStack(spacing: CoupleTheme.Space.large) {
            Text("Welcome back, \(firstName).")
                .font(.system(.title, weight: .medium))
                .tracking(CoupleTheme.TypeToken.displayTracking)
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
            Text("Opening your shared world…")
                .font(CoupleTheme.TypeToken.body)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct HomeErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: CoupleTheme.Space.large) {
            Text("Your shared world is still here.")
                .font(.system(.title, weight: .medium))
                .tracking(CoupleTheme.TypeToken.displayTracking)
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
                .multilineTextAlignment(.center)
            InlineMessage(text: message, style: .error)
            PrimaryButton(title: "Try again", action: retry)
        }
        .frame(maxWidth: CoupleTheme.Size.panel)
    }
}
