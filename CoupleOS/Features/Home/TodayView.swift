import ComposableArchitecture
import SwiftUI

struct TodaySheet: View {
    let store: StoreOf<TodayFeature>
    let connectionError: DailyExperienceError?
    let reconnect: () -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.large) {
            Eyebrow(text: strings.today.eyebrow)

            Text(strings.today.prompt(store.experience))
                .font(.system(.title, weight: .medium))
                .tracking(CoupleTheme.TypeToken.displayTracking)
                .foregroundStyle(CoupleTheme.ColorToken.pearl)

            moment

            if let error = store.error {
                InlineMessage(text: strings.errors.dailyExperience(error), style: .error)
            }

            if let connectionError {
                InlineMessage(
                    text: strings.errors.dailyExperience(connectionError),
                    style: .error
                )
                Button(strings.today.reconnect, action: reconnect)
                    .foregroundStyle(CoupleTheme.ColorToken.accent)
                    .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
            }

            Button(strings.today.backToOurWorld) {
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
        let choices = strings.today.options(store.experience)
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: CoupleTheme.Space.small),
                GridItem(.flexible(), spacing: CoupleTheme.Space.small)
            ],
            spacing: CoupleTheme.Space.small
        ) {
            ForEach(choices.indices, id: \.self) { index in
                OptionCard(
                    text: choices[index],
                    isSelected: store.selectedOption == index
                ) {
                    store.send(.optionTapped(index))
                }
            }
        }

        if store.selectedOption != nil {
            PrimaryButton(
                title: store.isSubmitting ? strings.today.saving : strings.today.leaveThisHere,
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
    @Environment(\.strings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
            Text(strings.today.waitingTitle)
                .font(.system(.headline, weight: .medium))
                .foregroundStyle(CoupleTheme.ColorToken.mint)
            Text(strings.today.waitingDetail)
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

    @Environment(\.strings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.medium) {
            Text(strings.today.revealTitle)
                .font(.system(.headline, weight: .medium))
                .foregroundStyle(CoupleTheme.ColorToken.mint)

            let choices = strings.today.options(experience)
            ForEach(experience.revealedAnswers?.keys.sorted() ?? [], id: \.self) { userID in
                if let index = experience.revealedAnswers?[userID],
                   choices.indices.contains(index) {
                    VStack(alignment: .leading, spacing: CoupleTheme.Space.xSmall) {
                        Text(userID == currentUserID ? strings.today.you : strings.today.yourPerson)
                            .font(CoupleTheme.TypeToken.caption)
                            .foregroundStyle(CoupleTheme.ColorToken.tertiaryText)
                        Text(choices[index])
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
