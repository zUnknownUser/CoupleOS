import ComposableArchitecture
import SwiftUI

struct MarketSheet: View {
    @Bindable var store: StoreOf<MarketFeature>
    let partnerName: String?
    /// Injected so the screen can be previewed and reasoned about at a chosen
    /// moment; staleness is the only thing here that depends on the clock.
    var now: Date = Date()

    @Environment(\.strings) private var strings

    var body: some View {
        NavigationStack {
            ZStack {
                CoupleBackground()
                content
            }
            .navigationTitle(strings.market.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(CoupleTheme.ColorToken.space)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .idle, .loading:
            ProgressView()
                .controlSize(.large)
                .tint(CoupleTheme.ColorToken.pearl)
                .accessibilityLabel(strings.market.openingList)

        case let .error(error):
            VStack(spacing: CoupleTheme.Space.large) {
                Text(strings.market.listStillHere)
                    .font(.system(.title2, weight: .medium))
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    .multilineTextAlignment(.center)
                InlineMessage(text: strings.errors.market(error), style: .error)
                PrimaryButton(title: strings.common.tryAgain) { store.send(.retryTapped) }
            }
            .frame(maxWidth: CoupleTheme.Size.panel)
            .padding(.horizontal, CoupleTheme.Space.gutter)

        case .ready:
            list
        }
    }

    private var list: some View {
        ScrollView(.vertical) {
            VStack(spacing: CoupleTheme.Space.medium) {
                MarketRunBanner(
                    run: store.activeRun,
                    isMine: store.myRun != nil,
                    partnerName: partnerName,
                    pendingCount: store.pending.count,
                    isChanging: store.isChangingRun
                ) {
                    store.send(.runButtonTapped)
                }

                MarketComposer(
                    name: $store.draftName,
                    isRequest: $store.draftIsRequest,
                    canSubmit: store.canSubmitDraft,
                    isSending: store.isAddingItem,
                    partnerName: partnerName,
                    someoneIsShopping: store.activeRun != nil
                ) {
                    store.send(.addItemTapped)
                }

                if let error = store.error {
                    Button { store.send(.dismissErrorTapped) } label: {
                        InlineMessage(text: strings.errors.market(error), style: .error)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(strings.market.dismissMessageHint)
                }

                if store.pending.isEmpty && store.gathered.isEmpty {
                    MarketEmptyState()
                } else {
                    MarketItemGroup(
                        title: strings.market.toBringSection,
                        items: store.pending,
                        currentUserID: store.currentUserID,
                        partnerName: partnerName,
                        settling: store.settlingItemIDs,
                        now: now,
                        toggle: { store.send(.itemTapped($0)) },
                        remove: { store.send(.removeItemTapped($0)) }
                    )

                    MarketItemGroup(
                        title: strings.market.basketSection,
                        items: store.gathered,
                        currentUserID: store.currentUserID,
                        partnerName: partnerName,
                        settling: store.settlingItemIDs,
                        now: now,
                        trailing: store.canClearBasket
                            ? MarketItemGroup.Trailing(
                                title: strings.market.clearBasket,
                                action: { store.send(.clearBasketTapped) }
                            )
                            : nil,
                        toggle: { store.send(.itemTapped($0)) },
                        remove: { store.send(.removeItemTapped($0)) }
                    )
                }
            }
            .frame(maxWidth: CoupleTheme.Size.homeMaxContentWidth)
            .frame(maxWidth: .infinity)
            .safeAreaPadding(.horizontal, CoupleTheme.Space.gutter)
            .safeAreaPadding(.vertical, CoupleTheme.Space.medium)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

/// The module's whole reason to exist, given the top of its own screen.
private struct MarketRunBanner: View {
    let run: MarketRun?
    let isMine: Bool
    let partnerName: String?
    let pendingCount: Int
    let isChanging: Bool
    let toggle: () -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.medium) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: eyebrow, tint: tint)
                Spacer(minLength: CoupleTheme.Space.small)
                if run != nil {
                    Circle().fill(tint).frame(width: 6, height: 6)
                }
            }

            Text(headline)
                .font(.system(.title3, weight: .medium))
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // The partner's run is theirs to end. Everyone else just watches.
            if run == nil || isMine {
                PrimaryButton(
                    title: isMine ? strings.market.finishRun : strings.market.startRun,
                    isEnabled: !isChanging,
                    isLoading: isChanging,
                    action: toggle
                )
            }
        }
        .padding(CoupleTheme.Space.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface, in: .rect(cornerRadius: CoupleTheme.Radius.homeSurface))
        .overlay {
            RoundedRectangle(cornerRadius: CoupleTheme.Radius.homeSurface)
                .stroke(tint.opacity(run == nil ? 0.16 : 0.34), lineWidth: 0.75)
        }
    }

    private var eyebrow: String {
        guard run != nil else { return strings.market.runEyebrowIdle }
        return isMine ? strings.market.runEyebrowMine : strings.market.runEyebrowTheirs
    }

    private var headline: String {
        guard run != nil else { return strings.market.runHeadlineIdle(partnerName) }
        if isMine {
            return pendingCount == 0
                ? strings.market.runHeadlineAllGathered
                : strings.market.runHeadlineRemaining(pendingCount)
        }
        return strings.market.runHeadlineTheirs(partnerName)
    }

    private var tint: Color {
        run == nil ? CoupleTheme.ColorToken.tertiaryText : CoupleTheme.ColorToken.amber
    }

    private var surface: some ShapeStyle {
        LinearGradient(
            colors: [tint.opacity(run == nil ? 0.05 : 0.16), CoupleTheme.ColorToken.field],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct MarketComposer: View {
    @Binding var name: String
    @Binding var isRequest: Bool
    let canSubmit: Bool
    let isSending: Bool
    let partnerName: String?
    let someoneIsShopping: Bool
    let submit: () -> Void

    @Environment(\.strings) private var strings
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
            HStack(spacing: CoupleTheme.Space.small) {
                TextField("", text: $name, prompt: prompt)
                    .textFieldStyle(.plain)
                    .font(CoupleTheme.TypeToken.body)
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(submit)
                    .frame(maxWidth: .infinity, minHeight: CoupleTheme.Size.fieldHeight)
                    .padding(.horizontal, CoupleTheme.Space.medium)
                    .background(CoupleTheme.ColorToken.field, in: .rect(cornerRadius: CoupleTheme.Radius.field))
                    .overlay {
                        RoundedRectangle(cornerRadius: CoupleTheme.Radius.field)
                            .stroke(CoupleTheme.ColorToken.hairline, lineWidth: 0.75)
                    }

                CircularGlassButton(systemImage: isSending ? "ellipsis" : "plus", action: submit)
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : CoupleTheme.Opacity.disabled)
                    .accessibilityLabel(strings.market.addToList)
            }

            Toggle(isOn: $isRequest) {
                Text(askLabel)
                    .font(CoupleTheme.TypeToken.caption)
                    .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
            }
            .toggleStyle(.switch)
            .tint(CoupleTheme.ColorToken.amber.opacity(0.8))
            .padding(.horizontal, CoupleTheme.Space.xSmall)
        }
    }

    private var prompt: Text {
        Text(someoneIsShopping
            ? strings.market.composerPlaceholderShopping
            : strings.market.composerPlaceholderIdle)
            .foregroundStyle(CoupleTheme.ColorToken.tertiaryText)
    }

    private var askLabel: String { strings.market.askDirectly(partnerName) }
}

private struct MarketItemGroup: View {
    struct Trailing {
        let title: String
        let action: () -> Void
    }

    let title: String
    let items: [MarketItem]
    let currentUserID: String?
    let partnerName: String?
    let settling: Set<String>
    let now: Date
    var trailing: Trailing?
    let toggle: (String) -> Void
    let remove: (String) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
                HStack {
                    Eyebrow(text: title)
                    Spacer(minLength: CoupleTheme.Space.small)
                    if let trailing {
                        Button(trailing.title, action: trailing.action)
                            .font(CoupleTheme.TypeToken.caption)
                            .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                    }
                }
                .padding(.horizontal, CoupleTheme.Space.xSmall)

                CoupleInputGroup {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { CoupleDivider() }
                        MarketItemRow(
                            item: item,
                            isMine: item.requestedBy == currentUserID,
                            partnerName: partnerName,
                            isSettling: settling.contains(item.id),
                            now: now,
                            toggle: { toggle(item.id) },
                            remove: { remove(item.id) }
                        )
                    }
                }
            }
        }
    }
}

private struct MarketItemRow: View {
    let item: MarketItem
    let isMine: Bool
    let partnerName: String?
    let isSettling: Bool
    let now: Date
    let toggle: () -> Void
    let remove: () -> Void

    @Environment(\.strings) private var strings

    private var isStale: Bool { item.isStale(asOf: now) }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: CoupleTheme.Space.medium) {
                Image(systemName: item.isPending ? "circle" : "checkmark.circle.fill")
                    .font(.system(.title3, weight: .regular))
                    .foregroundStyle(
                        item.isPending
                            ? CoupleTheme.ColorToken.tertiaryText
                            : CoupleTheme.ColorToken.mint
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(CoupleTheme.TypeToken.body)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                        .strikethrough(!item.isPending, color: CoupleTheme.ColorToken.tertiaryText)
                        .multilineTextAlignment(.leading)

                    if let attribution {
                        Text(attribution)
                            .font(CoupleTheme.TypeToken.caption)
                            .foregroundStyle(
                                item.isRequest && item.isPending
                                    ? CoupleTheme.ColorToken.amber.opacity(0.9)
                                    : CoupleTheme.ColorToken.tertiaryText
                            )
                    }
                }

                Spacer(minLength: 0)

                if isSettling {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, CoupleTheme.Space.medium)
            .frame(maxWidth: .infinity, minHeight: CoupleTheme.Size.fieldHeight, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isSettling)
        // Gathered things recede; so does anything nobody has acted on for
        // weeks. Both are still here — neither is still asking.
        .opacity(item.isPending ? (isStale ? 0.5 : 1) : 0.62)
        .contextMenu {
            Button(strings.common.remove, systemImage: "trash", role: .destructive, action: remove)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var attribution: String? {
        if isStale {
            // How long is the fact that makes "do you still want this?"
            // answerable, so the age replaces the attribution rather than
            // crowding in beside it.
            let days = item.daysWaiting(asOf: now)
            return days >= 30
                ? strings.market.waitingAMonthOrMore
                : strings.market.waitingDays(days)
        }
        if item.isRequest && item.isPending {
            return isMine
                ? strings.market.youAskedForThis
                : strings.market.personAskedForThis(partnerName)
        }
        return isMine ? nil : strings.market.addedByPerson(partnerName)
    }

    private var accessibilityLabel: String {
        let state = item.isPending ? strings.market.stillToBring : strings.market.inTheBasket
        return [item.name, state, attribution].compactMap { $0 }.joined(separator: ", ")
    }
}

private struct MarketEmptyState: View {
    @Environment(\.strings) private var strings

    var body: some View {
        VStack(spacing: CoupleTheme.Space.small) {
            Text(strings.market.emptyTitle)
                .font(.system(.headline, weight: .medium))
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
            Text(strings.market.emptyDetail)
                .font(CoupleTheme.TypeToken.body)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CoupleTheme.Space.large)
        .accessibilityElement(children: .combine)
    }
}
