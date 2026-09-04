import ComposableArchitecture
import SwiftUI

/// Decisions, given the screen its area tile promises. The sections are the
/// ones the Home used to carry inline — they only changed address.
struct DecisionsSheet: View {
    @Bindable var store: StoreOf<DecisionsFeature>
    let partnerName: String?

    var body: some View {
        NavigationStack {
            ZStack {
                CoupleBackground()

                ScrollView(.vertical) {
                    VStack(spacing: CoupleTheme.Space.large) {
                        NewDecisionButton { store.send(.createTapped) }

                        DecisionNeedsYouSection(
                            decisions: store.needsMyResponse,
                            partnerName: partnerName,
                            open: { store.send(.decisionTapped($0)) }
                        )

                        DecisionWaitingSection(
                            decisions: store.waitingForPartner,
                            partnerName: partnerName,
                            open: { store.send(.decisionTapped($0)) }
                        )

                        DecisionRecentSection(
                            decisions: store.recent,
                            open: { store.send(.decisionTapped($0)) }
                        )

                        if case let .error(message) = store.phase {
                            DecisionsRecovery(message: message) {
                                store.send(.retryTapped)
                            }
                        }
                    }
                    .frame(maxWidth: CoupleTheme.Size.homeMaxContentWidth)
                    .frame(maxWidth: .infinity)
                    .safeAreaPadding(.horizontal, CoupleTheme.Space.gutter)
                    .safeAreaPadding(.vertical, CoupleTheme.Space.medium)
                }
            }
            .navigationTitle("Decisions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(CoupleTheme.ColorToken.space)
        .preferredColorScheme(.dark)
        .sheet(
            item: $store.scope(state: \.destination?.create, action: \.destination.create)
        ) { createStore in
            CreateDecisionSheet(store: createStore)
        }
        .sheet(
            item: $store.scope(state: \.destination?.detail, action: \.destination.detail)
        ) { detailStore in
            DecisionDetailSheet(store: detailStore)
        }
    }
}
