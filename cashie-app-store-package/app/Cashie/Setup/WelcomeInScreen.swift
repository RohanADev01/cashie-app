import SwiftUI

struct WelcomeInScreen: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ConfettiBackground()

            VStack(spacing: 14) {
                Text("WELCOME IN")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(4)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .padding(.top, 8)

                ZStack {
                    Circle().fill(Theme.Palette.goldPastel).frame(width: 96, height: 96)
                        .shadow(color: Theme.Palette.gold.opacity(0.3), radius: 20, x: 0, y: 10)
                    Image(systemName: "checkmark")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(Theme.Palette.gold)
                }
                .padding(.top, 28)

                EmphasizedHeadline(
                    raw: "<em>You're in.</em>",
                    font: AppFont.display(48, weight: .bold)
                )
                .padding(.top, 8)

                Text("Last 90 seconds. Three quick wins.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)

                VStack(spacing: 8) {
                    step("01", "Grant 2 permissions")
                    step("02", "Set up Quick Log")
                    step("03", "Log your first spend")
                }
                .padding(.top, 24)

                Spacer()

                PrimaryButton(title: "Let's go") {
                    container.advanceOnboarding(to: .nameInput)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 70)
            .padding(.bottom, 28)
        }
    }

    private func step(_ num: String, _ label: String) -> some View {
        HStack(spacing: 14) {
            Text(num)
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(Theme.Palette.gold)
            Text(label)
                .font(AppFont.callout)
                .foregroundColor(Theme.Palette.ink)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Palette.line, lineWidth: 1))
    }
}

/// Pure-SwiftUI confetti. Pieces fall from above the screen down past the
/// bottom edge. Each piece animates itself on appear using `withAnimation`
/// so the per-piece delay + duration land correctly (a global
/// `.animation(_:value:)` on `.position` doesn't interpolate the way you'd
/// expect for ternary-driven values).
///
/// Use `.celebration` for big moments (reveal, post-paywall) - bigger pieces,
/// brighter palette, plays once. `.soft` is the looped ambient version.
struct ConfettiBackground: View {
    enum Style { case soft, celebration }
    var style: Style = .soft

    // Holding pieces in @State keeps them stable across parent re-renders.
    // Otherwise a parent that ticks every second (e.g. a live countdown) would
    // re-init this struct, regenerate the array with new UUIDs, and each
    // ConfettiPiece would re-fire its onAppear — confetti would re-fall every tick.
    @State private var pieces: [Confetti] = []

    init(style: Style = .soft) {
        self.style = style
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPiece(
                        piece: piece,
                        canvasHeight: proxy.size.height,
                        canvasWidth: proxy.size.width,
                        loops: style == .soft
                    )
                }
            }
            .onAppear {
                if pieces.isEmpty {
                    pieces = Self.makePieces(style: style)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func makePieces(style: Style) -> [Confetti] {
        let count = style == .celebration ? 60 : 28
        let palette: [Color] = style == .celebration
            ? [
                Color(hex: 0x04BA74), Color(hex: 0x1FCC83),
                Color(hex: 0xFFC84D), Color(hex: 0xFF823C),
                Color(hex: 0xE89AAA), Color(hex: 0x8AAAD9),
                Color(hex: 0xFFE6A0), Color.white,
            ]
            : [Theme.Palette.gold, Theme.Palette.goldLight,
               Theme.Palette.ink, Color(hex: 0x1be598)]
        let sizeRange: ClosedRange<CGFloat> = style == .celebration ? 6...14 : 4...10
        let durationRange: ClosedRange<Double> = style == .celebration ? 2.6...4.4 : 2.4...4.2
        let delayRange: ClosedRange<Double> = style == .celebration ? 0...1.4 : 0...0.8
        let startYRange: ClosedRange<CGFloat> = style == .celebration ? -0.20 ... -0.02 : -0.10 ... -0.02
        return (0..<count).map { _ in
            Confetti(
                x: CGFloat.random(in: 0...1),
                startY: CGFloat.random(in: startYRange),
                color: palette.randomElement()!,
                size: CGFloat.random(in: sizeRange),
                delay: Double.random(in: delayRange),
                duration: Double.random(in: durationRange)
            )
        }
    }
}

private struct ConfettiPiece: View {
    let piece: Confetti
    let canvasHeight: CGFloat
    let canvasWidth: CGFloat
    let loops: Bool

    @State private var fallen = false

    var body: some View {
        let startY = piece.startY * canvasHeight
        let endY = canvasHeight + 40
        Circle()
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size)
            .position(
                x: piece.x * canvasWidth,
                y: fallen ? endY : startY
            )
            .opacity(fallen ? 0.75 : 1)
            .onAppear {
                let anim: Animation = loops
                    ? .easeIn(duration: piece.duration)
                        .delay(piece.delay)
                        .repeatForever(autoreverses: false)
                    : .easeIn(duration: piece.duration).delay(piece.delay)
                withAnimation(anim) { fallen = true }
            }
    }
}

private struct Confetti: Identifiable {
    let id = UUID()
    let x: CGFloat
    let startY: CGFloat
    let color: Color
    let size: CGFloat
    let delay: Double
    let duration: Double
}
