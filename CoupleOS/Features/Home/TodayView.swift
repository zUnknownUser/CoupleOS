import ComposableArchitecture
import SwiftUI

struct TodaySheet: View {
    let store: StoreOf<TodayFeature>
    let connectionError: String?
    let reconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.large) {
            Eyebrow(text: "TODAY")

            Text(store.experience.prompt)
                .font(.system(.title, weight: .medium))
                .tracking(CoupleTheme.TypeToken.displayTracking)
                .foregroundStyle(CoupleTheme.ColorToken.pearl)

            moment

            if let errorMessage = store.errorMessage {
                InlineMessage(text: errorMessage, style: .error)
            }

            if let connectionError {
                InlineMessage(text: connectionError, style: .error)
                Button("Reconnect", action: reconnect)
                    .foregroundStyle(CoupleTheme.ColorToken.accent)
                    .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
            }

            Button("Back to our world") {
                store.send(.dismissTapped)
            }
            .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
            .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
        }
        .padding(CoupleTheme.Space.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .background(CoupleTheme.ColorToken.space)
    }

    private var detents: Set<PresentationDetent> {
        switch store.status {
        case .available, .waitingForMe, .revealAvailable:
            [.large]
        case .waitingForPartner:
            [.medium]
        }
    }

    @ViewBuilder
    private var moment: some View {
        switch store.status {
        case .available, .waitingForMe:
            options
        case .waitingForPartner:
            WaitingForPartnerNote()
        case .revealAvailable:
            RevealView(experience: store.experience, currentUserID: store.currentUserID)
        }
    }

    @ViewBuilder
    private var options: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: CoupleTheme.Space.small),
                GridItem(.flexible(), spacing: CoupleTheme.Space.small)
            ],
            spacing: CoupleTheme.Space.small
        ) {
            ForEach(store.experience.options.indices, id: \.self) { index in
                OptionCard(
                    text: store.experience.options[index],
                    isSelected: store.selectedOption == index
                ) {
                    store.send(.optionTapped(index))
                }
            }
        }

        if store.selectedOption != nil {
            PrimaryButton(
                title: store.isSubmitting ? "Saving…" : "Leave this here",
                isEnabled: !store.isSubmitting
            ) {
                store.send(.submitTapped)
            }
        }
    }
}

private struct OptionCard: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(CoupleTheme.TypeToken.body)
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(CoupleTheme.Space.medium)
                .frame(minHeight: 92, alignment: .topLeading)
                .background(
                    isSelected
                        ? CoupleTheme.ColorToken.accent.opacity(0.14)
                        : CoupleTheme.ColorToken.field,
                    in: .rect(cornerRadius: CoupleTheme.Radius.field)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: CoupleTheme.Radius.field)
                        .stroke(
                            isSelected ? CoupleTheme.ColorToken.accent : CoupleTheme.ColorToken.hairline,
                            lineWidth: isSelected ? 1.5 : 0.75
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct WaitingForPartnerNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
            Text("Your answer is here.")
                .font(.system(.headline, weight: .medium))
                .foregroundStyle(CoupleTheme.ColorToken.mint)
            Text("It stays private until your person leaves theirs. You can keep using your world meanwhile.")
                .font(CoupleTheme.TypeToken.body)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CoupleTheme.Space.medium)
        .background(CoupleTheme.ColorToken.field, in: .rect(cornerRadius: CoupleTheme.Radius.field))
        .accessibilityElement(children: .combine)
    }
}

private struct RevealView: View {
    let experience: DailyExperience
    let currentUserID: String

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.medium) {
            Text("You both left a mark here.")
                .font(.system(.headline, weight: .medium))
                .foregroundStyle(CoupleTheme.ColorToken.mint)

            ForEach(experience.revealedAnswers?.keys.sorted() ?? [], id: \.self) { userID in
                if let index = experience.revealedAnswers?[userID],
                   experience.options.indices.contains(index) {
                    VStack(alignment: .leading, spacing: CoupleTheme.Space.xSmall) {
                        Text(userID == currentUserID ? "You" : "Your person")
                            .font(CoupleTheme.TypeToken.caption)
                            .foregroundStyle(CoupleTheme.ColorToken.tertiaryText)
                        Text(experience.options[index])
                            .font(CoupleTheme.TypeToken.body)
                            .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    }
                }
            }
        }
        .padding(CoupleTheme.Space.medium)
        .background(CoupleTheme.ColorToken.field, in: .rect(cornerRadius: CoupleTheme.Radius.homeSurface))
    }
}
