import ComposableArchitecture
import SwiftUI

struct AuthenticatedView: View {
    @Bindable var store: StoreOf<AuthenticatedFeature>

    var body: some View {
        Group {
            switch store.couple {
            case .loading:
                HomeLoadingView(firstName: store.session.user.firstName)

            case .connected:
                HomeView(
                    store: store,
                    homeStore: store.scope(state: \.home, action: \.home)
                )

            case let .error(error):
                HomeErrorView(error: error) {
                    store.send(.retryTapped)
                }
            }
        }
        .task { await store.send(.task).finish() }
        .sheet(item: $store.route) { route in
            switch route {
            case .market:
                MarketSheet(
                    store: store.scope(state: \.market, action: \.market),
                    partnerName: store.home.partnerName
                )
            case .chores:
                ChoresSheet(
                    store: store.scope(state: \.chores, action: \.chores),
                    partnerName: store.home.partnerName
                )
            case .decisions:
                DecisionsSheet(
                    store: store.scope(state: \.decisions, action: \.decisions),
                    partnerName: store.home.partnerName
                )
            }
        }
    }
}

/// The Home: what needs the couple now, then the whole of what they share.
///
/// Both halves are built from `HomeComposition`, so neither one knows what a
/// Market or a Decision is. An area added later appears in both without this
/// view being edited.
struct HomeView: View {
    @Bindable var store: StoreOf<AuthenticatedFeature>
    @Bindable var homeStore: StoreOf<HomeFeature>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.strings) private var strings

    var body: some View {
        let composition = store.state.composition(strings: strings)

        VStack(spacing: CoupleTheme.Space.large) {
            CoupleHeader(
                currentUser: store.session.user,
                partner: store.home.partner,
                isSigningOut: store.isSigningOut,
                signOut: { store.send(.signOutTapped) }
            )

            if composition.isQuiet {
                HomeQuietState()
            } else {
                HomeNowSection(signals: composition.signals) {
                    store.send(.openTapped($0))
                }
            }

            HomeAreasSection(areas: composition.areas) {
                store.send(.openTapped($0))
            }

            if let signOutError = store.signOutError {
                InlineMessage(text: strings.errors.authentication(signOutError), style: .error)
            }

            if case let .error(error) = store.home.partner {
                PartnerRecovery(error: error) {
                    store.send(.home(.retryPartnerTapped))
                }
            }
        }
        .padding(.vertical, CoupleTheme.Space.small)
        .animation(reduceMotion ? nil : CoupleTheme.Motion.organic, value: store.home.partner)
        .sheet(
            item: $homeStore.scope(state: \.destination?.today, action: \.destination.today)
        ) { todayStore in
            TodaySheet(
                store: todayStore,
                connectionError: homeStore.dailyError,
                reconnect: { homeStore.send(.retryDailyTapped) }
            )
        }
    }
}
