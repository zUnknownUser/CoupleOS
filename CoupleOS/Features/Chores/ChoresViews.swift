import ComposableArchitecture
import SwiftUI

struct ChoresSheet: View {
    @Bindable var store: StoreOf<ChoresFeature>
    let partnerName: String?
    var now: Date = Date()

    @Environment(\.strings) private var strings

    var body: some View {
        NavigationStack {
            ZStack {
                CoupleBackground()
                content
            }
            .navigationTitle(strings.chores.title)
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
                .accessibilityLabel(strings.chores.openingChores)

        case let .error(error):
            VStack(spacing: CoupleTheme.Space.large) {
                Text(strings.chores.listStillHere)
                    .font(.system(.title2, weight: .medium))
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
                InlineMessage(text: strings.errors.chore(error), style: .error)
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
                ChoreComposer(
                    title: $store.draftTitle,
                    cadence: $store.draftCadence,
                    rotation: $store.draftRotation,
                    startsWithMe: $store.draftStartsWithMe,
                    partnerName: partnerName,
                    canSubmit: store.canSubmitDraft,
                    isSending: store.isCreating
                ) {
                    store.send(.createTapped)
                }

                if let error = store.error {
                    Button { store.send(.dismissErrorTapped) } label: {
                        InlineMessage(text: strings.errors.chore(error), style: .error)
                    }
                    .buttonStyle(.plain)
                }

                if store.active.isEmpty {
                    ChoresEmptyState()
                } else {
                    ChoreGroup(
                        title: strings.chores.yourTurnSection,
                        chores: store.state.mine(asOf: now),
                        partnerName: partnerName,
                        currentUserID: store.currentUserID,
                        settling: store.settlingChoreIDs,
                        now: now,
                        isActionable: true,
                        complete: { store.send(.completeTapped($0)) },
                        remove: { store.send(.removeTapped($0)) }
                    )

                    ChoreGroup(
                        title: strings.chores.withPartnerSection(partnerName),
                        chores: store.state.theirs(asOf: now),
                        partnerName: partnerName,
                        currentUserID: store.currentUserID,
                        settling: store.settlingChoreIDs,
                        now: now,
                        isActionable: false,
                        complete: { _ in },
                        remove: { store.send(.removeTapped($0)) }
                    )

                    ChoreGroup(
                        title: strings.chores.comingUpSection,
                        chores: store.state.upcoming(asOf: now),
                        partnerName: partnerName,
                        currentUserID: store.currentUserID,
                        settling: store.settlingChoreIDs,
                        now: now,
                        isActionable: true,
                        complete: { store.send(.completeTapped($0)) },
                        remove: { store.send(.removeTapped($0)) }
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

private struct ChoreComposer: View {
    @Binding var title: String
    @Binding var cadence: ChoresFeature.DraftCadence
    @Binding var rotation: Chore.Rotation
    @Binding var startsWithMe: Bool
    let partnerName: String?
    let canSubmit: Bool
    let isSending: Bool
    let submit: () -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
            HStack(spacing: CoupleTheme.Space.small) {
                TextField("", text: $title, prompt: Text(strings.chores.composerPlaceholder)
                    .foregroundStyle(CoupleTheme.ColorToken.tertiaryText))
                    .textFieldStyle(.plain)
                    .font(CoupleTheme.TypeToken.body)
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
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
                    .accessibilityLabel(strings.chores.addChore)
            }

            ScrollView(.horizontal) {
                HStack(spacing: CoupleTheme.Space.xSmall) {
                    ForEach(ChoresFeature.DraftCadence.allCases, id: \.self) { option in
                        ChoreChip(title: strings.chores.cadence(option), isOn: option == cadence) {
                            cadence = option
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: CoupleTheme.Space.xSmall) {
                ForEach(Chore.Rotation.allCases, id: \.self) { option in
                    ChoreChip(title: strings.chores.rotation(option), isOn: option == rotation) {
                        rotation = option
                    }
                }
            }

            if rotation != .anyone {
                Toggle(isOn: $startsWithMe) {
                    Text(startsWithMe
                        ? strings.chores.startsWithYou
                        : strings.chores.startsWithPartner(partnerName))
                        .font(CoupleTheme.TypeToken.caption)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                }
                .toggleStyle(.switch)
                .tint(CoupleTheme.ColorToken.mint.opacity(0.7))
                .padding(.horizontal, CoupleTheme.Space.xSmall)
            }
        }
    }
}

private struct ChoreChip: View {
    let title: String
    let isOn: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            Text(title)
                .font(CoupleTheme.TypeToken.caption)
                .foregroundStyle(isOn ? CoupleTheme.ColorToken.space : CoupleTheme.ColorToken.secondaryText)
                .padding(.horizontal, CoupleTheme.Space.small)
                .frame(minHeight: 32)
                .background(
                    isOn ? CoupleTheme.ColorToken.accent : CoupleTheme.ColorToken.field,
                    in: .capsule
                )
                .overlay {
                    Capsule().stroke(CoupleTheme.ColorToken.hairline, lineWidth: isOn ? 0 : 0.75)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

private struct ChoreGroup: View {
    let title: String
    let chores: [Chore]
    let partnerName: String?
    let currentUserID: String?
    let settling: Set<String>
    let now: Date
    let isActionable: Bool
    let complete: (String) -> Void
    let remove: (String) -> Void

    var body: some View {
        if !chores.isEmpty {
            VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
                Eyebrow(text: title)
                    .padding(.leading, CoupleTheme.Space.xSmall)

                CoupleInputGroup {
                    ForEach(Array(chores.enumerated()), id: \.element.id) { index, chore in
                        if index > 0 { CoupleDivider() }
                        ChoreRow(
                            chore: chore,
                            partnerName: partnerName,
                            currentUserID: currentUserID,
                            isSettling: settling.contains(chore.id),
                            isActionable: isActionable,
                            now: now,
                            complete: { complete(chore.id) },
                            remove: { remove(chore.id) }
                        )
                    }
                }
            }
        }
    }
}

private struct ChoreRow: View {
    let chore: Chore
    let partnerName: String?
    let currentUserID: String?
    let isSettling: Bool
    let isActionable: Bool
    let now: Date
    let complete: () -> Void
    let remove: () -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        Button(action: complete) {
            HStack(spacing: CoupleTheme.Space.medium) {
                Image(systemName: isActionable ? "circle" : "clock")
                    .font(.system(.title3, weight: .regular))
                    .foregroundStyle(mark)

                VStack(alignment: .leading, spacing: 2) {
                    Text(chore.title)
                        .font(CoupleTheme.TypeToken.body)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(CoupleTheme.TypeToken.caption)
                        .foregroundStyle(subtitleTint)
                }

                Spacer(minLength: 0)

                if isSettling { ProgressView().controlSize(.small) }
            }
            .padding(.horizontal, CoupleTheme.Space.medium)
            .frame(maxWidth: .infinity, minHeight: CoupleTheme.Size.fieldHeight, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isSettling || !isActionable)
        .opacity(isActionable ? 1 : 0.72)
        .contextMenu {
            Button(strings.common.remove, systemImage: "trash", role: .destructive, action: remove)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(chore.title), \(subtitle)")
        .accessibilityAddTraits(isActionable ? .isButton : [])
        .accessibilityHint(isActionable ? strings.chores.markDoneHint : "")
    }

    private var subtitle: String {
        let standing = chore.standing(asOf: now)
        guard standing != .settled else { return strings.chores.standingDone }
        return strings.chores.rowSubtitle(
            strings.chores.turn(chore, currentUserID: currentUserID, partnerName: partnerName),
            strings.chores.standing(standing)
        )
    }

    private var mark: Color {
        if case .overdue = chore.standing(asOf: now) { return CoupleTheme.ColorToken.amber }
        return isActionable
            ? CoupleTheme.ColorToken.tertiaryText
            : CoupleTheme.ColorToken.tertiaryText.opacity(0.7)
    }

    private var subtitleTint: Color {
        if case .overdue = chore.standing(asOf: now) { return CoupleTheme.ColorToken.amber.opacity(0.9) }
        return CoupleTheme.ColorToken.tertiaryText
    }
}

private struct ChoresEmptyState: View {
    @Environment(\.strings) private var strings

    var body: some View {
        VStack(spacing: CoupleTheme.Space.small) {
            Text(strings.chores.emptyTitle)
                .font(.system(.headline, weight: .medium))
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
            Text(strings.chores.emptyDetail)
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

