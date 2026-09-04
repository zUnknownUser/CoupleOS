import SwiftUI

struct DecisionNeedsYouSection: View {
    let decisions: [Decision]
    let partnerName: String?
    let open: (String) -> Void

    var body: some View {
        if !decisions.isEmpty {
            DecisionHomeSection(title: "NEEDS YOU", tint: CoupleTheme.ColorToken.amber) {
                ForEach(decisions) { decision in
                    DecisionHomeRow(
                        decision: decision,
                        detail: "\(partnerName ?? "Your person") needs your choice",
                        tint: CoupleTheme.ColorToken.amber
                    ) {
                        open(decision.id)
                    }
                }
            }
        }
    }
}

struct DecisionWaitingSection: View {
    let decisions: [Decision]
    let partnerName: String?
    let open: (String) -> Void

    var body: some View {
        if !decisions.isEmpty {
            DecisionHomeSection(title: "WAITING", tint: CoupleTheme.ColorToken.tertiaryText) {
                ForEach(decisions) { decision in
                    DecisionHomeRow(
                        decision: decision,
                        detail: partnerName.map { "Waiting quietly for \($0) to choose" }
                            ?? "Waiting quietly for your person",
                        tint: CoupleTheme.ColorToken.tertiaryText
                    ) {
                        open(decision.id)
                    }
                }
            }
        }
    }
}

struct DecisionRecentSection: View {
    let decisions: [Decision]
    let open: (String) -> Void

    var body: some View {
        if !decisions.isEmpty {
            DecisionHomeSection(title: "RECENT", tint: CoupleTheme.ColorToken.mint) {
                ForEach(Array(decisions.prefix(3))) { decision in
                    DecisionHomeRow(
                        decision: decision,
                        detail: decision.selectedOption.map { "You decided together · \($0)" }
                            ?? "Decided together",
                        tint: CoupleTheme.ColorToken.mint
                    ) {
                        open(decision.id)
                    }
                }
            }
        }
    }
}

struct DecisionsRecovery: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
            InlineMessage(text: message, style: .error)
            Button("Reconnect decisions", action: retry)
                .font(CoupleTheme.TypeToken.caption)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                .frame(minHeight: CoupleTheme.Size.minimumTouchTarget)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DecisionHomeSection<Content: View>: View {
    let title: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
            Eyebrow(text: title, tint: tint)
            VStack(spacing: CoupleTheme.Space.small) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DecisionHomeRow: View {
    let decision: Decision
    let detail: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CoupleTheme.Space.medium) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.12))
                    Image(systemName: decision.status == .resolved ? "checkmark" : "arrow.turn.down.right")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: CoupleTheme.Space.xSmall) {
                    Text(decision.title)
                        .font(.system(.headline, weight: .medium))
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(CoupleTheme.TypeToken.caption)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(CoupleTheme.ColorToken.tertiaryText)
            }
            .padding(CoupleTheme.Space.medium)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(CoupleTheme.ColorToken.field, in: .rect(cornerRadius: CoupleTheme.Radius.field))
            .overlay {
                RoundedRectangle(cornerRadius: CoupleTheme.Radius.field)
                    .stroke(tint.opacity(0.16), lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(decision.title). \(detail).")
        .accessibilityHint("Opens this decision")
    }
}

struct NewDecisionButton: View {
    let action: () -> Void

    var body: some View {
        GlassButton(action: action) {
            Label("New decision", systemImage: "plus")
                .font(CoupleTheme.TypeToken.button)
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
                .frame(maxWidth: .infinity, minHeight: CoupleTheme.Size.buttonHeight)
        }
        .accessibilityHint("Creates something for your person to choose")
    }
}
