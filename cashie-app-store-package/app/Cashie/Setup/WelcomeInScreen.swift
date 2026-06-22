import SwiftUI

/// First screen after the paywall. Celebrates that they're in and captures
/// their first name in the same step, so post-paywall setup starts on the
/// name input and not a roadmap they don't need to read.
struct WelcomeInScreen: View {
    @EnvironmentObject var container: AppContainer
    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
                    font: AppFont.display(44, weight: .bold)
                )
                .padding(.top, 8)

                Text("First, what should we call you?")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)

                TextField("Your first name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($nameFocused)
                    .font(AppFont.text(20, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                trimmed.isEmpty ? Theme.Palette.line : Theme.Palette.gold,
                                lineWidth: 1
                            )
                    )
                    .submitLabel(.done)
                    .onSubmit(commit)
                    .padding(.top, 18)

                Spacer()

                PrimaryButton(title: "That's me") { commit() }
                    .opacity(trimmed.isEmpty ? 0.55 : 1)
                    .disabled(trimmed.isEmpty)
            }
            .padding(.horizontal, 28)
            .padding(.top, 70)
            .padding(.bottom, 28)
        }
        .onAppear {
            if container.user.hasName {
                name = container.user.firstName
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                nameFocused = true
            }
        }
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        container.user.firstName = String(trimmed.prefix(40))
        container.advanceOnboarding(to: .permissions)
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
