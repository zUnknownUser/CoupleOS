import SwiftUI

extension HomeSignal.Urgency {
    /// State, not category, decides colour here — the same rule the rest of the
    /// app already follows. Which area a signal came from is carried by its
    /// symbol, so a busy Home still reads as one object.
    var tint: Color {
        switch self {
        case .live, .needsYou, .needsBoth: CoupleTheme.ColorToken.amber
        case .waiting: CoupleTheme.ColorToken.tertiaryText
        case .settled: CoupleTheme.ColorToken.mint
        }
    }

    var worldActivity: SharedWorldView.Activity {
        switch self {
        case .live: .live
        case .needsYou: .needsYou
        case .needsBoth: .needsBoth
        case .waiting: .waiting
        case .settled: .sharedMoment
        }
    }
}

/// Everything asking for the couple's attention, loudest first.
struct HomeNowSection: View {
    let signals: [HomeSignal]
    let open: (HomeSignal.Target) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.strings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
            Eyebrow(text: strings.home.nowSection)
                .padding(.leading, CoupleTheme.Space.xSmall)

            ForEach(signals) { signal in
                SignalCard(signal: signal) { open(signal.target) }
            }
        }
        .animation(reduceMotion ? nil : CoupleTheme.Motion.organic, value: signals)
    }
}

struct SignalCard: View {
    let signal: HomeSignal
    let open: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.strings) private var strings

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: CoupleTheme.Space.medium) {
                mark

                VStack(alignment: .leading, spacing: CoupleTheme.Space.xSmall) {
                    Eyebrow(text: eyebrow, tint: signal.urgency.tint)

                    Text(signal.title)
                        .font(.system(.headline, weight: .medium))
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(signal.detail)
                        .font(CoupleTheme.TypeToken.caption)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(CoupleTheme.ColorToken.tertiaryText)
                    .padding(.top, 2)
            }
            .padding(CoupleTheme.Space.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surface, in: .rect(cornerRadius: CoupleTheme.Radius.homeSurface))
            .overlay {
                RoundedRectangle(cornerRadius: CoupleTheme.Radius.homeSurface)
                    .stroke(
                        signal.urgency.tint.opacity(signal.urgency == .live ? 0.34 : 0.18),
                        lineWidth: 0.75
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            strings.home.signalAccessibility(eyebrow, signal.title, signal.detail)
        )
        .accessibilityAddTraits(.isButton)
    }

    private var eyebrow: String { strings.home.urgencyEyebrow(signal.urgency) }

    @ViewBuilder
    private var mark: some View {
        ZStack {
            if signal.urgency == .live {
                LivePulse(tint: signal.urgency.tint)
            }
            Image(systemName: signal.symbol)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(signal.urgency.tint)
        }
        .frame(width: 34, height: 34)
        .background(signal.urgency.tint.opacity(0.12), in: .circle)
        .accessibilityHidden(true)
    }

    private var surface: some ShapeStyle {
        LinearGradient(
            colors: [
                signal.urgency.tint.opacity(signal.urgency == .live ? 0.16 : 0.085),
                reduceTransparency
                    ? CoupleTheme.ColorToken.opaqueField
                    : CoupleTheme.ColorToken.field
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// The one thing on the Home that moves by itself, for the one state that is
/// running out while you look at it.
private struct LivePulse: View {
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        Circle()
            .stroke(tint.opacity(expanded ? 0 : 0.55), lineWidth: 1)
            .scaleEffect(expanded ? 1.5 : 0.75)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.9).repeatForever(autoreverses: false)) {
                    expanded = true
                }
            }
    }
}

/// The couple's map of itself. Always complete, even when nothing is urgent —
/// this is the half of the Home that tells them what the app *is*.
struct HomeAreasSection: View {
    let areas: [ModuleSummary]
    let open: (HomeSignal.Target) -> Void

    @Environment(\.strings) private var strings

    private let columns = [
        GridItem(.flexible(), spacing: CoupleTheme.Space.small),
        GridItem(.flexible(), spacing: CoupleTheme.Space.small)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
            Eyebrow(text: strings.home.ourWorldSection)
                .padding(.leading, CoupleTheme.Space.xSmall)

            LazyVGrid(columns: columns, spacing: CoupleTheme.Space.small) {
                ForEach(areas) { area in
                    AreaTile(area: area) { open(area.target) }
                }
            }
        }
    }
}

struct AreaTile: View {
    let area: ModuleSummary
    let open: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.strings) private var strings

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
                HStack(spacing: CoupleTheme.Space.xSmall) {
                    Image(systemName: area.module.symbol)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(tint)
                    Spacer(minLength: 0)
                    if area.isLive {
                        Circle()
                            .fill(CoupleTheme.ColorToken.amber)
                            .frame(width: 6, height: 6)
                    } else if area.attention > 0 {
                        Text("\(area.attention)")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(CoupleTheme.ColorToken.space)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(CoupleTheme.ColorToken.amber, in: .circle)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    Text(area.status)
                        .font(CoupleTheme.TypeToken.caption)
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(CoupleTheme.Space.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                reduceTransparency
                    ? CoupleTheme.ColorToken.opaqueField
                    : CoupleTheme.ColorToken.field,
                in: .rect(cornerRadius: CoupleTheme.Radius.fieldGroup)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CoupleTheme.Radius.fieldGroup)
                    .stroke(
                        area.isLive
                            ? CoupleTheme.ColorToken.amber.opacity(0.34)
                            : CoupleTheme.ColorToken.hairline,
                        lineWidth: 0.75
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(strings.home.areaAccessibility(title, area.status))
        .accessibilityAddTraits(.isButton)
    }

    private var title: String { strings.home.moduleTitle(area.module) }

    private var tint: Color {
        if area.isLive { return CoupleTheme.ColorToken.amber }
        if area.attention > 0 { return CoupleTheme.ColorToken.amber }
        return CoupleTheme.ColorToken.pearl.opacity(0.7)
    }
}

/// What the Home says when nothing is asking for anything. Not an error state —
/// a quiet couple is the normal case, and it should feel like rest.
struct HomeQuietState: View {
    @Environment(\.strings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
            Eyebrow(text: strings.home.nowSection)
                .padding(.leading, CoupleTheme.Space.xSmall)

            HStack(spacing: CoupleTheme.Space.medium) {
                ZStack {
                    Circle()
                        .stroke(CoupleTheme.ColorToken.hairline, lineWidth: 1)
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(CoupleTheme.ColorToken.mint.opacity(0.7))
                        .frame(width: 6, height: 6)
                        .offset(x: -5)
                    Circle()
                        .fill(CoupleTheme.ColorToken.amber.opacity(0.7))
                        .frame(width: 6, height: 6)
                        .offset(x: 5)
                }
                .accessibilityHidden(true)

                Text(strings.home.quiet)
                    .font(CoupleTheme.TypeToken.body)
                    .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(CoupleTheme.Space.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                CoupleTheme.ColorToken.field.opacity(0.5),
                in: .rect(cornerRadius: CoupleTheme.Radius.homeSurface)
            )
        }
        .accessibilityElement(children: .combine)
    }
}
