import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    let store: StoreOf<AppFeature>
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let destinationStore = store.scope(state: \.destination, action: \.destination)
        GeometryReader { proxy in
            ZStack {
                CoupleBackground()
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        // One slot, one control, in every phase. The wordmark
                        // stays centred and the language sits at the edge beside
                        // it — two faint letters that matter only to whoever the
                        // phone guessed wrong about. On the Home the wordmark is
                        // gone but the slot stays, which keeps the control out of
                        // the header: that row already carries two monograms,
                        // both names and sign-out, and a third control pushed the
                        // names into an ellipsis as soon as the copy was longer
                        // than English.
                        Group {
                            if isAuthenticated {
                                Color.clear.frame(height: 0)
                            } else {
                                BrandLockup()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .trailing) { LanguageControl() }
                        .padding(.bottom, isWelcome ? CoupleTheme.Space.large : CoupleTheme.Space.small)

                        // The world belongs to the shell in every phase, at one
                        // size per phase. It used to be drawn here for everyone
                        // *except* the couple, who got a second 320pt copy from
                        // HomeView — two presentations of the same object, and
                        // the shell fell silent exactly where the world is real.
                        SharedWorldView(
                            isCompact: !isWelcome,
                            isShared: worldIsShared,
                            activity: worldActivity
                        )
                            .frame(width: worldSize(in: proxy.size), height: worldSize(in: proxy.size))

                        if let worldCaption {
                            Text(worldCaption)
                                .font(CoupleTheme.TypeToken.body)
                                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.top, CoupleTheme.Space.small)
                                .accessibilityAddTraits(.isHeader)
                        }

                        Color.clear
                            .frame(height: isWelcome ? CoupleTheme.Space.large : CoupleTheme.Space.medium)

                        destination(store: destinationStore)
                            .id(destinationID)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    .frame(maxWidth: isAuthenticated
                        ? CoupleTheme.Size.homeMaxContentWidth
                        : CoupleTheme.Size.maxContentWidth)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .safeAreaPadding(.horizontal, CoupleTheme.Space.gutter)
                    .safeAreaPadding(.top, CoupleTheme.Space.medium)
                    .safeAreaPadding(.bottom, CoupleTheme.Space.large)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .environment(\.strings, strings)
        .environment(\.languageSettings, languageSettings)
        .preferredColorScheme(.dark)
        .animation(CoupleTheme.Motion.organic, value: destinationID)
        .sensoryFeedback(.impact(weight: .light), trigger: destinationID)
        .task { await store.send(.task).finish() }
        .onOpenURL { store.send(.openURL($0)) }
    }

    /// The one place the catalogue enters the view tree. Everything below
    /// reads it from the environment, so a language change is a single value
    /// changing at the root and the whole app redrawing in it.
    private var strings: Strings { .of(store.localization.language) }

    private var languageSettings: LanguageSettings {
        LanguageSettings(
            preference: store.localization.preference,
            systemLanguage: store.localization.systemLanguage,
            options: store.localization.options,
            select: { store.send(.localization(.preferenceSelected($0))) }
        )
    }

    @ViewBuilder
    private func destination(store: StoreOf<AppFeature.Destination>) -> some View {
        switch store.state {
        case .launching:
            if let store = store.scope(state: \.launching, action: \.launching) { LaunchingPanel(store: store) }
        case .unauthenticated:
            if let store = store.scope(state: \.unauthenticated, action: \.unauthenticated) { UnauthenticatedView(store: store) }
        case .profileProvisioning:
            if let store = store.scope(state: \.profileProvisioning, action: \.profileProvisioning) { ProfileProvisioningPanel(store: store) }
        case .resolvingSession:
            if let store = store.scope(state: \.resolvingSession, action: \.resolvingSession) { SessionResolutionPanel(store: store) }
        case .onboarding:
            if let store = store.scope(state: \.onboarding, action: \.onboarding) { OnboardingView(store: store) }
        case .authenticated:
            if let store = store.scope(state: \.authenticated, action: \.authenticated) { AuthenticatedView(store: store) }
        }
    }

    private var isWelcome: Bool {
        guard case let .unauthenticated(state) = store.destination,
              case .welcome = state.destination else { return false }
        return true
    }

    private var isAuthenticated: Bool {
        if case .authenticated = store.destination { return true }
        return false
    }

    private var destinationID: String {
        switch store.destination {
        case .launching: "launching"
        case let .unauthenticated(state):
            switch state.destination {
            case .welcome: "welcome"
            case .login: "login"
            case let .accountCreation(accountCreation):
                switch accountCreation.destination {
                case .identity: "identity"
                case .signUp: "signUp"
                }
            case .invite: "invite"
            }
        case .profileProvisioning: "profileProvisioning"
        case .resolvingSession: "resolvingSession"
        case let .onboarding(state):
            switch state.destination {
            case .profileRecovery: "profileRecovery"
            case .readyForPartner: "readyForPartner"
            case .inviteAcceptance: "inviteAcceptance"
            }
        case .authenticated: "authenticated"
        }
    }

    private var worldIsShared: Bool {
        switch store.destination {
        case let .onboarding(onboarding):
            switch onboarding.destination {
            case let .readyForPartner(state):
                if case .partnerJoined = state.phase { return true }
                return false
            case let .inviteAcceptance(state):
                if case .joined = state.phase { return true }
                return false
            case .profileRecovery:
                return false
            }
        case let .authenticated(state):
            // The hero used to decide this from the couple itself; the shell
            // inherits that test rather than assuming every session is a pair.
            guard case let .connected(couple) = state.couple else { return false }
            return couple.status == .active && couple.memberIDs.count == 2
        case .launching, .profileProvisioning, .resolvingSession:
            return false
        case let .unauthenticated(state):
            if case .welcome = state.destination { return true }
            return false
        }
    }

    /// The line that carried the home's warmth when the world was the hero
    /// there. It survives the demotion by moving under the orb, one line
    /// instead of a 430pt block. Only the couple sees it — before that there is
    /// no "both".
    ///
    /// Both this and `worldActivity` now read the Home's composition rather
    /// than reaching into named modules, so an area added later reaches the
    /// world without this file being touched.
    private var worldCaption: String? {
        guard let composition else { return nil }
        guard let leading = composition.leading else { return strings.world.bothHere }
        return leading.worldCaption ?? strings.world.urgencyCaption(leading.urgency)
    }

    private var worldActivity: SharedWorldView.Activity {
        composition?.leading?.urgency.worldActivity ?? .calm
    }

    private var composition: HomeComposition? {
        guard case let .authenticated(authenticated) = store.destination else { return nil }
        return authenticated.composition(strings: strings)
    }

    private func worldSize(in size: CGSize) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return isWelcome
                ? CoupleTheme.Size.accessibilityWorld
                : CoupleTheme.Size.accessibilityCompactWorld
        }
        if isAuthenticated { return CoupleTheme.Size.homeWorld }
        guard isWelcome else { return CoupleTheme.Size.compactWorld }
        return min(CoupleTheme.Size.maxWorld, max(
            CoupleTheme.Size.minWorld,
            min(size.width * 0.72, size.height * 0.34)
        ))
    }
}

private struct UnauthenticatedView: View {
    let store: StoreOf<UnauthenticatedFeature>
    @ViewBuilder var body: some View {
        let destinationStore = store.scope(state: \.destination, action: \.destination)
        switch destinationStore.state {
        case .welcome:
            if let store = destinationStore.scope(state: \.welcome, action: \.welcome) { WelcomeHero(store: store) }
        case .login:
            if let store = destinationStore.scope(state: \.login, action: \.login) { LoginPanel(store: store) }
        case .accountCreation:
            if let store = destinationStore.scope(state: \.accountCreation, action: \.accountCreation) { AccountCreationView(store: store) }
        case .invite:
            if let store = destinationStore.scope(state: \.invite, action: \.invite) { InvitePanel(store: store) }
        }
    }
}

private struct AccountCreationView: View {
    let store: StoreOf<AccountCreationFeature>
    @ViewBuilder var body: some View {
        let destinationStore = store.scope(state: \.destination, action: \.destination)
        switch destinationStore.state {
        case .identity:
            if let store = destinationStore.scope(state: \.identity, action: \.identity) { IdentityPanel(store: store) }
        case .signUp:
            if let store = destinationStore.scope(state: \.signUp, action: \.signUp) { CreateAccountPanel(store: store) }
        }
    }
}

private struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>
    @ViewBuilder var body: some View {
        let destinationStore = store.scope(state: \.destination, action: \.destination)
        switch destinationStore.state {
        case .profileRecovery:
            if let store = destinationStore.scope(state: \.profileRecovery, action: \.profileRecovery) { ProfileRecoveryPanel(store: store) }
        case .readyForPartner:
            if let store = destinationStore.scope(state: \.readyForPartner, action: \.readyForPartner) { ReadyForPartnerPanel(store: store) }
        case .inviteAcceptance:
            if let store = destinationStore.scope(state: \.inviteAcceptance, action: \.inviteAcceptance) { InviteAcceptancePanel(store: store) }
        }
    }
}

private struct BrandLockup: View {
    @Environment(\.strings) private var strings

    var body: some View {
        HStack(spacing: CoupleTheme.Space.small) {
            ZStack {
                Circle().fill(CoupleTheme.ColorToken.mint).frame(width: 7, height: 7).offset(x: -4)
                Circle().fill(CoupleTheme.ColorToken.amber).frame(width: 7, height: 7).offset(x: 4)
            }
            .frame(width: 24, height: 24)
            .overlay { Circle().stroke(CoupleTheme.ColorToken.hairline, lineWidth: 0.75) }
            Text(strings.brand.wordmark)
                .font(CoupleTheme.TypeToken.brand)
                .tracking(CoupleTheme.TypeToken.eyebrowTracking)
                .foregroundStyle(CoupleTheme.ColorToken.pearl.opacity(0.88))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(strings.brand.accessibleName)
    }
}

private struct LaunchingPanel: View {
    let store: StoreOf<LaunchingFeature>

    @Environment(\.strings) private var strings

    var body: some View {
        Text(strings.welcome.openingYourWorld)
            .font(CoupleTheme.TypeToken.body)
            .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
            .frame(maxWidth: CoupleTheme.Size.panel)
    }
}

#Preview("Welcome") {
    ContentView(store: Store(initialState: AppFeature.State()) { AppFeature() })
}
