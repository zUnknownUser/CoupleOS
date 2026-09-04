import AuthenticationServices
import SwiftUI
import UIKit

struct PasswordField: View {
    @Binding var password: String
    let isVisible: Bool
    let isEnabled: Bool
    let contentType: UITextContentType
    let toggle: () -> Void
    var body: some View {
        CoupleInlineField(label: "PASSWORD") {
            HStack(spacing: CoupleTheme.Space.small) {
                Group {
                    if isVisible { TextField("Your password", text: $password) }
                    else { SecureField("Your password", text: $password) }
                }
                .textContentType(contentType)
                .disabled(!isEnabled)
                Button(action: toggle) {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .accessibilityLabel(isVisible ? "Hide password" : "Show password")
            }
        }
    }
}

struct FormPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let backAction: (() -> Void)?
    @ViewBuilder let content: Content
    @ScaledMetric(relativeTo: .title) private var titleSize = CoupleTheme.TypeToken.titleSize

    init(title: String, subtitle: String, backAction: (() -> Void)?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.backAction = backAction
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.Space.large) {
            if let backAction {
                CircularGlassButton(systemImage: "chevron.left", action: backAction)
                    .accessibilityLabel("Back")
            }
            VStack(alignment: .leading, spacing: CoupleTheme.Space.small) {
                Text(title)
                    .font(.system(size: titleSize, weight: .medium))
                    .tracking(-0.75)
                    .foregroundStyle(CoupleTheme.ColorToken.pearl)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(CoupleTheme.TypeToken.body)
                    .foregroundStyle(CoupleTheme.ColorToken.secondaryText)
                    .lineSpacing(2)
            }
            VStack(spacing: CoupleTheme.Space.medium) { content }
        }
        .frame(maxWidth: CoupleTheme.Size.panel)
    }
}

struct OrDivider: View {
    var body: some View {
        HStack(spacing: CoupleTheme.Space.medium) {
            Rectangle().fill(CoupleTheme.ColorToken.hairline).frame(height: 0.5)
            Text("OR").font(CoupleTheme.TypeToken.caption).foregroundStyle(CoupleTheme.ColorToken.tertiaryText)
            Rectangle().fill(CoupleTheme.ColorToken.hairline).frame(height: 0.5)
        }
        .accessibilityHidden(true)
    }
}

struct FieldMessage: View {
    let text: String
    var body: some View {
        Text(text)
            .font(CoupleTheme.TypeToken.caption)
            .foregroundStyle(CoupleTheme.ColorToken.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CoupleTheme.Space.medium)
            .accessibilityLabel("Error: \(text)")
    }
}

struct InlineMessage: View {
    enum Style { case error, success }
    let text: String
    let style: Style
    var body: some View {
        Label(text, systemImage: style == .error ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
            .font(CoupleTheme.TypeToken.caption)
            .foregroundStyle(style == .error ? CoupleTheme.ColorToken.error : CoupleTheme.ColorToken.mint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("\(style == .error ? "Error" : "Success"): \(text)")
    }
}

struct PrivacyNote: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "lock.fill")
            .font(CoupleTheme.TypeToken.caption)
            .foregroundStyle(CoupleTheme.ColorToken.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .padding(.top, CoupleTheme.Space.xSmall)
    }
}

struct AppleSignInControl: UIViewRepresentable {
    let action: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .whiteOutline)
        button.cornerRadius = CoupleTheme.Size.buttonHeight / 2
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
    }
    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}
