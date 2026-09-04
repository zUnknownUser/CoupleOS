import SwiftUI

enum CoupleTheme {
    enum ColorToken {
        static let space = Color(red: 0.025, green: 0.034, blue: 0.055)
        static let deepOcean = Color(red: 0.035, green: 0.10, blue: 0.14)
        static let warmShadow = Color(red: 0.13, green: 0.075, blue: 0.08)
        static let pearl = Color(red: 0.95, green: 0.96, blue: 0.95)
        static let secondaryText = pearl.opacity(0.68)
        static let tertiaryText = pearl.opacity(0.52)
        static let mint = Color(red: 0.44, green: 0.88, blue: 0.76)
        static let amber = Color(red: 1.0, green: 0.71, blue: 0.43)
        static let error = Color(red: 1.0, green: 0.55, blue: 0.52)
        static let accent = Color(red: 0.86, green: 0.95, blue: 0.90)
        static let field = Color.white.opacity(0.065)
        static let hairline = Color.white.opacity(0.12)
        static let opaqueControl = Color(red: 0.17, green: 0.18, blue: 0.20)
        static let opaqueField = Color(red: 0.15, green: 0.16, blue: 0.18)
        static let worldSea = Color(red: 0.10, green: 0.25, blue: 0.27)
        static let worldCore = Color(red: 0.045, green: 0.075, blue: 0.11)
        static let worldWarm = Color(red: 0.14, green: 0.085, blue: 0.09)
    }

    enum Space {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 12
        static let medium: CGFloat = 20
        static let large: CGFloat = 32
        static let xLarge: CGFloat = 48

        /// The single horizontal inset every screen breathes inside. Deliberately
        /// not one of the steps above: the scale grows for vertical rhythm, while
        /// the gutter has to stay narrow enough for a 375pt phone.
        static let gutter: CGFloat = 24
    }

    enum Radius {
        static let field: CGFloat = 20
        static let fieldGroup: CGFloat = 24
        static let homeSurface: CGFloat = 28
    }

    enum Opacity {
        static let disabled = 0.48
    }

    enum Size {
        static let minimumTouchTarget: CGFloat = 44
        static let buttonHeight: CGFloat = 52
        static let fieldHeight: CGFloat = 54

        /// The one column width every panel measures. Panels that do the same
        /// job used to measure 390, 400, 420 and 440 — differences nobody chose.
        static let panel: CGFloat = 420
        static let maxContentWidth: CGFloat = 520
        static let homeMaxContentWidth: CGFloat = 680

        /// The world's size per phase. On Home it is the living center of the
        /// couple, large enough to carry state without pushing the useful
        /// context below the first natural scroll.
        static let homeWorld: CGFloat = 224
        static let compactWorld: CGFloat = 124
        static let accessibilityCompactWorld: CGFloat = 96
        static let accessibilityWorld: CGFloat = 188
        static let minWorld: CGFloat = 200
        static let maxWorld: CGFloat = 312
    }

    enum Motion {
        static let standard = 0.60
        static let reveal = 1.35

        static let organic = Animation.spring(duration: standard, bounce: 0.08)
        static let gentle = Animation.easeInOut(duration: reveal)
    }

    enum TypeToken {
        static let heroSize: CGFloat = 40
        static let titleSize: CGFloat = 30
        static let brand = Font.system(.subheadline, design: .default, weight: .semibold)
        static let body = Font.system(.body, design: .default)
        static let button = Font.system(.headline, design: .default, weight: .semibold)
        static let caption = Font.system(.caption, design: .default, weight: .medium)

        /// Section labels. Heavier than `caption` on purpose — an eyebrow that
        /// reads as faint punctuation stops naming the section below it.
        static let eyebrow = Font.system(.caption, design: .default, weight: .semibold)
        static let eyebrowTracking: CGFloat = 2.2

        /// Optical tightening for display sizes. Large type set at default
        /// tracking reads loose; every `.title`-and-up headline takes this.
        static let displayTracking: CGFloat = -0.5
    }
}

struct CoupleBackground: View {
    var body: some View {
        ZStack {
            CoupleTheme.ColorToken.space

            RadialGradient(
                colors: [CoupleTheme.ColorToken.deepOcean.opacity(0.72), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 560
            )

            RadialGradient(
                colors: [CoupleTheme.ColorToken.warmShadow.opacity(0.62), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 500
            )

            Canvas { context, size in
                let stars: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.08, 0.16, 1.2), (0.17, 0.63, 0.7), (0.27, 0.09, 0.8),
                    (0.39, 0.78, 1.0), (0.55, 0.17, 0.6), (0.67, 0.69, 0.7),
                    (0.79, 0.12, 1.0), (0.88, 0.52, 0.8), (0.94, 0.84, 0.6)
                ]

                for star in stars {
                    let rect = CGRect(
                        x: size.width * star.0,
                        y: size.height * star.1,
                        width: star.2,
                        height: star.2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.22)))
                }
            }
        }
        .ignoresSafeArea()
    }
}
