import SwiftUI

struct CoupleField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.xSmall) {
            Text(label)
                .font(CoupleTheme.TypeToken.caption)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)

            content
                .font(CoupleTheme.TypeToken.body)
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
                .frame(maxWidth: .infinity, minHeight: CoupleTheme.Size.fieldHeight, alignment: .leading)
                .padding(.horizontal, CoupleTheme.Space.medium)
                .background(
                    reduceTransparency
                        ? CoupleTheme.ColorToken.opaqueField
                        : CoupleTheme.ColorToken.field,
                    in: .rect(cornerRadius: CoupleTheme.Radius.field)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: CoupleTheme.Radius.field)
                        .stroke(CoupleTheme.ColorToken.hairline, lineWidth: 0.75)
                }
        }
    }
}

struct CoupleInputGroup<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            reduceTransparency
                ? CoupleTheme.ColorToken.opaqueField
                : CoupleTheme.ColorToken.field,
            in: .rect(cornerRadius: CoupleTheme.Radius.fieldGroup)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CoupleTheme.Radius.fieldGroup)
                .stroke(CoupleTheme.ColorToken.hairline, lineWidth: 0.75)
        }
    }
}

struct CoupleInlineField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.xSmall) {
            Text(label)
                .font(CoupleTheme.TypeToken.caption)
                .foregroundStyle(CoupleTheme.ColorToken.secondaryText)

            content
                .font(CoupleTheme.TypeToken.body)
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        }
        .padding(.horizontal, CoupleTheme.Space.medium)
        .padding(.vertical, CoupleTheme.Space.small)
        .frame(minHeight: 70)
    }
}

struct Eyebrow: View {
    let text: String
    var tint = CoupleTheme.ColorToken.secondaryText

    var body: some View {
        Text(text)
            .font(CoupleTheme.TypeToken.eyebrow)
            .tracking(CoupleTheme.TypeToken.eyebrowTracking)
            .foregroundStyle(tint)
    }
}

struct CoupleDivider: View {
    var body: some View {
        Rectangle()
            .fill(CoupleTheme.ColorToken.hairline)
            .frame(height: 0.5)
            .padding(.horizontal, CoupleTheme.Space.medium)
            .accessibilityHidden(true)
    }
}

struct PrimaryButton: View {
    let title: String
    var isEnabled = true
    var isLoading = false
    let action: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.strings) private var strings

    @ViewBuilder
    var body: some View {
        if reduceTransparency {
            Button(action: action) { label }
                .buttonStyle(.plain)
                .background(
                    CoupleTheme.ColorToken.accent.opacity(isEnabled ? 1 : 0.42),
                    in: .capsule
                )
                .foregroundStyle(CoupleTheme.ColorToken.space)
                .disabled(!isEnabled)
        } else {
            Button(action: action) { label }
                .buttonStyle(.glassProminent)
                .tint(CoupleTheme.ColorToken.accent.opacity(isEnabled ? 0.94 : 0.38))
                .foregroundStyle(CoupleTheme.ColorToken.space)
                .disabled(!isEnabled)
        }
    }

    private var label: some View {
        ZStack {
            Text(title)
                .opacity(isLoading ? 0 : 1)
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(strings.common.working)
            }
        }
        .font(CoupleTheme.TypeToken.button)
        .frame(maxWidth: .infinity, minHeight: CoupleTheme.Size.buttonHeight)
    }
}

struct GlassButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    var body: some View {
        if reduceTransparency {
            Button(action: action) { label }
                .buttonStyle(.plain)
                .background(CoupleTheme.ColorToken.opaqueControl, in: .capsule)
                .overlay {
                    Capsule().stroke(CoupleTheme.ColorToken.hairline, lineWidth: 0.75)
                }
        } else {
            Button(action: action) { label }
                .buttonStyle(.glass)
        }
    }
}

struct CircularGlassButton: View {
    let systemImage: String
    let action: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    var body: some View {
        if reduceTransparency {
            button
                .buttonStyle(.plain)
                .background(CoupleTheme.ColorToken.opaqueControl, in: .circle)
                .overlay {
                    Circle().stroke(CoupleTheme.ColorToken.hairline, lineWidth: 0.75)
                }
        } else {
            button.buttonStyle(.glass)
        }
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(.body, design: .default, weight: .semibold))
                .foregroundStyle(CoupleTheme.ColorToken.pearl)
                .frame(
                    width: CoupleTheme.Size.minimumTouchTarget,
                    height: CoupleTheme.Size.minimumTouchTarget
                )
        }
    }
}

struct OutlinedButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
        .background(
            reduceTransparency
                ? CoupleTheme.ColorToken.opaqueControl
                : CoupleTheme.ColorToken.field,
            in: .capsule
        )
        .overlay {
            Capsule().stroke(CoupleTheme.ColorToken.hairline, lineWidth: 0.75)
        }
    }
}
