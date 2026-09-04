import SwiftUI

/// Two presences bending the same quiet field.
struct SharedWorldView: View {
    enum Activity: Equatable {
        case calm
        case needsBoth
        case needsYou
        case waiting
        case sharedMoment
        /// One of them is out in the world right now. The only activity that
        /// moves on its own — everything else here waits.
        case live
    }

    let isCompact: Bool
    let isShared: Bool
    let activity: Activity

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.strings) private var strings
    @State private var appeared = false
    @State private var sharedProgress: CGFloat = 0
    @State private var interaction: CGSize = .zero
    @State private var pressure: CGFloat = 0

    init(
        isCompact: Bool,
        isShared: Bool,
        activity: Activity = .calm
    ) {
        self.isCompact = isCompact
        self.isShared = isShared
        self.activity = activity
    }

    var body: some View {
        TimelineView(.animation(
            minimumInterval: ResonanceMetrics.frameInterval,
            paused: reduceMotion
        )) { timeline in
            Canvas(
                opaque: false,
                colorMode: .linear,
                rendersAsynchronously: true
            ) { context, size in
                drawResonance(
                    in: &context,
                    size: size,
                    time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                )
            }
        }
        .scaleEffect(appeared ? 1 + pressure * 0.006 : 0.96)
        .opacity(appeared ? 1 : 0)
        .contentShape(.rect)
        .gesture(resonanceGesture)
        .onAppear {
            sharedProgress = isShared ? 1 : 0
            withAnimation(reduceMotion ? .linear(duration: 0.01) : CoupleTheme.Motion.gentle) {
                appeared = true
            }
        }
        .onChange(of: isShared) { _, value in
            withAnimation(reduceMotion ? .linear(duration: 0.01) : CoupleTheme.Motion.gentle) {
                sharedProgress = value ? 1 : 0
            }
        }
        .animation(reduceMotion ? nil : CoupleTheme.Motion.organic, value: activity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isImage)
    }

    private var resonanceGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !reduceMotion else { return }
                let distance = hypot(value.translation.width, value.translation.height)
                pressure = min(1, 0.12 + distance / 120)
                interaction = CGSize(
                    width: limited(value.translation.width * ResonanceMetrics.touchResponse),
                    height: limited(value.translation.height * ResonanceMetrics.touchResponse)
                )
            }
            .onEnded { _ in
                withAnimation(CoupleTheme.Motion.organic) {
                    interaction = .zero
                    pressure = 0
                }
            }
    }

    private func drawResonance(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        let dimension = min(size.width, size.height)
        let center = CGPoint(
            x: size.width * 0.5 + interaction.width * 0.18,
            y: size.height * 0.5 + interaction.height * 0.18
        )
        let radius = dimension * ResonanceMetrics.radiusFactor
        let points = presencePoints(center: center, radius: radius, time: time)

        drawAmbientField(center: center, radius: radius, in: &context)
        drawOrbitalStructure(center: center, radius: radius, time: time, in: &context)
        drawActivityTrace(
            center: center,
            points: points,
            radius: radius,
            time: time,
            in: &context
        )
        drawSharedLens(
            center: center,
            first: points.first,
            second: points.second,
            radius: radius,
            time: time,
            in: &context
        )
        drawPresence(
            at: points.first,
            radius: radius * (isCompact ? 0.10 : 0.115),
            color: CoupleTheme.ColorToken.mint,
            time: time,
            opacity: 1,
            in: &context
        )
        drawPresence(
            at: points.second,
            radius: radius * (isCompact ? 0.10 : 0.115),
            color: CoupleTheme.ColorToken.amber,
            time: time + 2.4,
            opacity: 0.12 + sharedProgress * 0.88,
            in: &context
        )
    }

    private func presencePoints(
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval
    ) -> (first: CGPoint, second: CGPoint) {
        let distant = radius * 0.59
        let together = radius * 0.31
        let activityPull: CGFloat = activity == .sharedMoment ? radius * 0.035 : 0
        let separation = distant + (together - distant) * sharedProgress
            - pressure * radius * 0.018
            - activityPull
        let firstDrift = CGFloat(sin(time * 0.083) + sin(time * 0.029 + 0.7)) * radius * 0.012
        let secondDrift = CGFloat(sin(time * 0.071 + 2.2) + sin(time * 0.033 + 4.0)) * radius * 0.012
        return (
            CGPoint(x: center.x - separation, y: center.y + firstDrift),
            CGPoint(x: center.x + separation, y: center.y + secondDrift)
        )
    }

    private func drawAmbientField(
        center: CGPoint,
        radius: CGFloat,
        in context: inout GraphicsContext
    ) {
        guard !reduceTransparency else { return }
        let bounds = CGRect(
            x: center.x - radius * 1.08,
            y: center.y - radius * 0.82,
            width: radius * 2.16,
            height: radius * 1.64
        )
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.16))
            layer.fill(
                Path(ellipseIn: bounds),
                with: .radialGradient(
                    Gradient(colors: [
                        CoupleTheme.ColorToken.deepOcean.opacity(0.3),
                        CoupleTheme.ColorToken.mint.opacity(0.055),
                        .clear
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius * 1.08
                )
            )
        }
    }

    private func drawOrbitalStructure(
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        in context: inout GraphicsContext
    ) {
        let rings: [(CGFloat, CGFloat, Double, Double)] = [
            (1.0, 0.62, 0.045, -8),
            (0.79, 0.48, -0.031, 13),
            (0.56, 0.33, 0.021, -18)
        ]

        for (index, ring) in rings.enumerated() {
            let rect = CGRect(
                x: center.x - radius * ring.0,
                y: center.y - radius * ring.1,
                width: radius * ring.0 * 2,
                height: radius * ring.1 * 2
            )
            let angle = Angle.degrees(ring.3 + sin(time * ring.2) * 4).radians
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: angle)
                .translatedBy(x: -center.x, y: -center.y)
            let path = Path(ellipseIn: rect).applying(transform)
            context.stroke(
                path,
                with: .color(.white.opacity(0.055 - Double(index) * 0.011)),
                style: StrokeStyle(
                    lineWidth: isCompact ? 0.45 : 0.7,
                    lineCap: .round,
                    dash: index == 1 ? [2, 9] : []
                )
            )
        }
    }

    private func drawSharedLens(
        center: CGPoint,
        first: CGPoint,
        second: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        in context: inout GraphicsContext
    ) {
        let strength = sharedProgress * activity.lensStrength
        guard strength > 0.01 else { return }
        let pulse = 1 + CGFloat(sin(time * 0.13) + sin(time * 0.047 + 1.5)) * 0.025
        let lensRadius = radius * (0.29 + pressure * 0.018) * pulse
        let bounds = CGRect(
            x: center.x - lensRadius,
            y: center.y - lensRadius * 0.72,
            width: lensRadius * 2,
            height: lensRadius * 1.44
        )

        context.drawLayer { layer in
            if !reduceTransparency { layer.addFilter(.blur(radius: radius * 0.055)) }
            layer.fill(
                Path(ellipseIn: bounds),
                with: .linearGradient(
                    Gradient(colors: [
                        CoupleTheme.ColorToken.mint.opacity(0.2 * strength),
                        .white.opacity(0.075 * strength),
                        CoupleTheme.ColorToken.amber.opacity(0.2 * strength)
                    ]),
                    startPoint: first,
                    endPoint: second
                )
            )
        }

        let inner = bounds.insetBy(dx: lensRadius * 0.3, dy: lensRadius * 0.2)
        context.stroke(
            Path(ellipseIn: inner),
            with: .color(.white.opacity(0.08 * strength)),
            lineWidth: isCompact ? 0.5 : 0.75
        )
    }

    private func drawActivityTrace(
        center: CGPoint,
        points: (first: CGPoint, second: CGPoint),
        radius: CGFloat,
        time: TimeInterval,
        in context: inout GraphicsContext
    ) {
        switch activity {
        case .calm:
            return

        case .needsBoth:
            let phase = reduceMotion ? 0.5 : (sin(time * 0.34) + 1) * 0.5
            drawSignalRing(
                at: center,
                radius: radius * (0.18 + CGFloat(phase) * 0.025),
                color: CoupleTheme.ColorToken.amber,
                opacity: 0.1,
                in: &context
            )

        case .needsYou:
            drawSignalArc(
                from: points.second,
                to: points.first,
                radius: radius,
                time: time,
                color: CoupleTheme.ColorToken.amber,
                in: &context
            )

        case .waiting:
            let phase = reduceMotion ? 0.4 : (sin(time * 0.27) + 1) * 0.5
            drawSignalRing(
                at: points.first,
                radius: radius * (0.2 + CGFloat(phase) * 0.035),
                color: CoupleTheme.ColorToken.mint,
                opacity: 0.12,
                in: &context
            )

        case .sharedMoment:
            let phase = reduceMotion ? 0.5 : (sin(time * 0.22) + 1) * 0.5
            drawSignalRing(
                at: center,
                radius: radius * (0.3 + CGFloat(phase) * 0.045),
                color: .white,
                opacity: 0.13,
                in: &context
            )
            drawSignalRing(
                at: center,
                radius: radius * (0.43 + CGFloat(phase) * 0.025),
                color: CoupleTheme.ColorToken.mint,
                opacity: 0.075,
                in: &context
            )

        case .live:
            drawTravellingPresence(center: center, radius: radius, time: time, in: &context)
        }
    }

    /// A mote making its way around the outer orbit and back.
    ///
    /// Every other activity pulses in place, because every other activity is
    /// waiting. This one travels: someone left the house, and the world says so
    /// by being the only thing here that goes somewhere.
    private func drawTravellingPresence(
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        in context: inout GraphicsContext
    ) {
        let orbit = (width: radius * 1.0, height: radius * 0.62)
        let angle = reduceMotion ? .pi * 0.25 : time * 0.42
        let trail = 5

        for step in 0...trail {
            let position = angle - Double(step) * 0.085
            let point = CGPoint(
                x: center.x + cos(position) * orbit.width,
                y: center.y + sin(position) * orbit.height
            )
            let fade = 1 - Double(step) / Double(trail + 1)
            let size = radius * (isCompact ? 0.028 : 0.036) * fade

            if step == 0, !reduceTransparency {
                context.fill(
                    circle(at: point, radius: size * 4.2),
                    with: .radialGradient(
                        Gradient(colors: [
                            CoupleTheme.ColorToken.amber.opacity(0.34),
                            .clear
                        ]),
                        center: point,
                        startRadius: 0,
                        endRadius: size * 4.2
                    )
                )
            }
            context.fill(
                circle(at: point, radius: max(size, 0.5)),
                with: .color(CoupleTheme.ColorToken.amber.opacity(0.9 * fade * fade))
            )
        }
    }

    private func drawSignalArc(
        from start: CGPoint,
        to end: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        color: Color,
        in context: inout GraphicsContext
    ) {
        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x - radius * 0.12, y: start.y - radius * 0.24),
            control2: CGPoint(x: end.x + radius * 0.12, y: end.y + radius * 0.24)
        )
        let shimmer = reduceMotion ? 0.11 : 0.09 + (sin(time * 0.31) + 1) * 0.025
        context.stroke(
            path,
            with: .color(color.opacity(shimmer)),
            style: StrokeStyle(
                lineWidth: isCompact ? 0.65 : 0.9,
                lineCap: .round,
                dash: [2, 8]
            )
        )
    }

    private func drawSignalRing(
        at point: CGPoint,
        radius: CGFloat,
        color: Color,
        opacity: Double,
        in context: inout GraphicsContext
    ) {
        context.stroke(
            circle(at: point, radius: radius),
            with: .color(color.opacity(opacity)),
            lineWidth: isCompact ? 0.55 : 0.8
        )
    }

    private func drawPresence(
        at point: CGPoint,
        radius: CGFloat,
        color: Color,
        time: TimeInterval,
        opacity: CGFloat,
        in context: inout GraphicsContext
    ) {
        let breathing = 1 + CGFloat(sin(time * 0.17) + sin(time * 0.061 + 1.1)) * 0.026
        let coreRadius = radius * breathing
        let haloRadius = coreRadius * (3.2 + pressure * 0.25)

        if !reduceTransparency {
            context.fill(
                circle(at: point, radius: haloRadius),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.32 * opacity), .clear]),
                    center: point,
                    startRadius: 0,
                    endRadius: haloRadius
                )
            )
        }

        context.fill(
            circle(at: point, radius: coreRadius),
            with: .radialGradient(
                Gradient(colors: [
                    .white.opacity(0.96 * opacity),
                    color.opacity(0.86 * opacity),
                    color.opacity(0.38 * opacity)
                ]),
                center: CGPoint(
                    x: point.x - coreRadius * 0.28,
                    y: point.y - coreRadius * 0.31
                ),
                startRadius: 0,
                endRadius: coreRadius * 1.3
            )
        )

        let resonanceRadius = coreRadius * 1.72
        context.stroke(
            circle(at: point, radius: resonanceRadius),
            with: .color(color.opacity(0.16 * opacity)),
            lineWidth: isCompact ? 0.5 : 0.8
        )
        context.stroke(
            circle(at: point, radius: resonanceRadius * 2.1),
            with: .color(color.opacity(0.045 * opacity)),
            lineWidth: isCompact ? 0.4 : 0.65
        )
    }

    private func circle(at point: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }

    private func limited(_ value: CGFloat) -> CGFloat {
        min(ResonanceMetrics.maximumOffset, max(-ResonanceMetrics.maximumOffset, value))
    }

    private var accessibilityDescription: String {
        guard isShared else { return strings.world.soloDescription }
        return strings.world.description(activity)
    }
}

private extension SharedWorldView.Activity {
    var lensStrength: CGFloat {
        switch self {
        case .calm: 0.78
        case .needsBoth: 0.9
        case .needsYou, .waiting: 0.86
        case .sharedMoment: 1.18
        case .live: 0.94
        }
    }
}

private enum ResonanceMetrics {
    static let frameInterval: TimeInterval = 1 / 20
    static let radiusFactor: CGFloat = 0.38
    static let touchResponse: CGFloat = 0.08
    static let maximumOffset: CGFloat = 12
}

#Preview {
    ZStack {
        CoupleBackground()
        SharedWorldView(isCompact: false, isShared: true)
            .frame(width: 310, height: 310)
    }
}
