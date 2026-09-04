import ComposableArchitecture
import SwiftUI

struct CreateDecisionSheet: View {
    let store: StoreOf<CreateDecisionFeature>
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case option(Int)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoupleTheme.Space.large) {
                sheetHeader(eyebrow: "NEW DECISION")

                VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
                    Text("What do you need their choice on?")
                        .font(.system(.title, weight: .medium))
                        .tracking(CoupleTheme.TypeToken.displayTracking)
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)

                    Text("Keep it small. One question, a few real options.")
                        .font(CoupleTheme.TypeToken.body)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                }

                CoupleField(label: "THE DECISION") {
                    TextField(
                        "What should we decide?",
                        text: Binding(
                            get: { store.title },
                            set: { store.send(.titleChanged($0)) }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(1...3)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .option(0) }
                }

                VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
                    Eyebrow(text: "CHOICES")

                    CoupleInputGroup {
                        ForEach(store.options.indices, id: \.self) { index in
                            HStack(spacing: CoupleTheme.Space.small) {
                                Text("\(index + 1)")
                                    .font(CoupleTheme.TypeToken.caption)
                                    .foregroundStyle(CoupleTheme.ColorToken.tertiaryText)
                                    .frame(width: 18)

                                TextField(
                                    "Add a choice",
                                    text: Binding(
                                        get: { store.options[index] },
                                        set: { store.send(.optionChanged(index: index, value: $0)) }
                                    )
                                )
                                .focused($focusedField, equals: .option(index))
                                .submitLabel(index == store.options.indices.last ? .done : .next)
                                .onSubmit {
                                    if store.options.indices.contains(index + 1) {
                                        focusedField = .option(index + 1)
                                    } else {
                                        focusedField = nil
                                    }
                                }

                                if store.options.count > 2 {
                                    Button {
                                        store.send(.removeOptionTapped(index))
                                    } label: {
                                        Image(systemName: "minus.circle")
                                            .foregroundStyle(CoupleTheme.ColorToken.tertiaryText)
                                            .frame(
                                                width: CoupleTheme.Size.minimumTouchTarget,
                                                height: CoupleTheme.Size.minimumTouchTarget
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove choice \(index + 1)")
                                }
                            }
                            .padding(.horizontal, CoupleTheme.Space.medium)
                            .frame(minHeight: CoupleTheme.Size.fieldHeight)

                            if index != store.options.indices.last {
                                CoupleDivider()
                            }
                        }
                    }

                    if store.options.count < 6 {
                        Button {
                            store.send(.addOptionTapped)
                        } label: {
                            Label("Add another choice", systemImage: "plus")
                                .font(CoupleTheme.TypeToken.caption)
                                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                                .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let validationMessage = store.validationMessage {
                    FieldMessage(text: validationMessage)
                }
                if let errorMessage = store.errorMessage {
                    InlineMessage(text: errorMessage, style: .error)
                }

                PrimaryButton(
                    title: "Send for their choice",
                    isEnabled: store.canSubmit,
                    isLoading: store.isSubmitting
                ) {
                    focusedField = nil
                    store.send(.submitTapped)
                }
            }
            .padding(CoupleTheme.Space.large)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDragIndicator(.visible)
        .background(CoupleTheme.ColorToken.space)
    }

    private func sheetHeader(eyebrow: String) -> some View {
        HStack {
            Eyebrow(text: eyebrow, tint: CoupleTheme.ColorToken.mint)
            Spacer()
            CircularGlassButton(systemImage: "xmark") {
                store.send(.dismissTapped)
            }
            .accessibilityLabel("Close")
        }
    }
}

struct DecisionDetailSheet: View {
    let store: StoreOf<DecisionDetailFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.large) {
            HStack {
                Eyebrow(text: eyebrow, tint: tint)
                Spacer()
                CircularGlassButton(systemImage: "xmark") {
                    store.send(.dismissTapped)
                }
                .accessibilityLabel("Close")
            }

            if let decision = store.decision {
                Text(decision.title)
                    .font(.system(.title, weight: .medium))
                    .tracking(CoupleTheme.TypeToken.displayTracking)
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    .fixedSize(horizontal: false, vertical: true)
            }

            detail

            if let errorMessage = store.errorMessage {
                InlineMessage(text: errorMessage, style: .error)
            }

            Spacer(minLength: 0)
        }
        .padding(CoupleTheme.Space.large)
        .presentationDragIndicator(.visible)
        .background(CoupleTheme.ColorToken.space)
    }

    @ViewBuilder
    private var detail: some View {
        switch store.presentation {
        case .needsMyResponse:
            choices
        case .resolving:
            choices
        case .waitingForPartner:
            DecisionStateNote(
                title: "You left this with your person.",
                detail: "It will settle here when they choose.",
                tint: CoupleTheme.ColorToken.amber
            )
        case .resolved:
            resolved
        case .unavailable:
            DecisionStateNote(
                title: "This decision isn't available.",
                detail: "It may have changed while your world was updating.",
                tint: CoupleTheme.ColorToken.tertiaryText
            )
        }
    }

    @ViewBuilder
    private var choices: some View {
        if let decision = store.decision {
            VStack(spacing: CoupleTheme.Space.small) {
                ForEach(decision.options.indices, id: \.self) { index in
                    DecisionChoiceButton(
                        text: decision.options[index],
                        isSelected: store.selectedOptionIndex == index
                    ) {
                        store.send(.optionTapped(index))
                    }
                }
            }

            PrimaryButton(
                title: "Choose this",
                isEnabled: store.selectedOptionIndex != nil && !store.isResolving,
                isLoading: store.isResolving
            ) {
                store.send(.resolveTapped)
            }
        }
    }

    @ViewBuilder
    private var resolved: some View {
        if let result = store.decision?.selectedOption {
            VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
                Label("Decided together", systemImage: "checkmark.circle.fill")
                    .font(CoupleTheme.TypeToken.caption)
                    .foregroundStyle(CoupleTheme.ColorToken.mint)
                Text(result)
                    .font(.system(.title2, weight: .semibold))
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    .fixedSize(horizontal: false, vertical: true)
                Text("One small thing settled inside your shared world.")
                    .font(CoupleTheme.TypeToken.body)
                    .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
            }
            .padding(CoupleTheme.Space.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                CoupleTheme.ColorToken.mint.opacity(0.09),
                in: .rect(cornerRadius: CoupleTheme.Radius.homeSurface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CoupleTheme.Radius.homeSurface)
                    .stroke(CoupleTheme.ColorToken.mint.opacity(0.22), lineWidth: 0.75)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var eyebrow: String {
        switch store.presentation {
        case .needsMyResponse, .resolving: "NEEDS YOU"
        case .waitingForPartner: "WAITING"
        case .resolved: "DECIDED"
        case .unavailable: "DECISION"
        }
    }

    private var tint: Color {
        switch store.presentation {
        case .resolved: CoupleTheme.ColorToken.mint
        case .needsMyResponse, .resolving, .waitingForPartner: CoupleTheme.ColorToken.amber
        case .unavailable: CoupleTheme.ColorToken.tertiaryText
        }
    }
}

private struct DecisionChoiceButton: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CoupleTheme.Space.medium) {
                Circle()
                    .strokeBorder(
                        isSelected ? CoupleTheme.ColorToken.accent : CoupleTheme.ColorToken.hairline,
                        lineWidth: isSelected ? 5 : 1
                    )
                    .frame(width: 22, height: 22)
                Text(text)
                    .font(CoupleTheme.TypeToken.body)
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CoupleTheme.Space.medium)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(
                isSelected ? CoupleTheme.ColorToken.accent.opacity(0.11) : CoupleTheme.ColorToken.field,
                in: .rect(cornerRadius: CoupleTheme.Radius.field)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CoupleTheme.Radius.field)
                    .stroke(
                        isSelected ? CoupleTheme.ColorToken.accent.opacity(0.7) : CoupleTheme.ColorToken.hairline,
                        lineWidth: isSelected ? 1.25 : 0.75
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct DecisionStateNote: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
            Text(title)
                .font(.system(.headline, weight: .medium))
                .foregroundStyle(tint)
            Text(detail)
                .font(CoupleTheme.TypeToken.body)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
        }
        .padding(CoupleTheme.Space.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoupleTheme.ColorToken.field, in: .rect(cornerRadius: CoupleTheme.Radius.field))
        .accessibilityElement(children: .combine)
    }
}
