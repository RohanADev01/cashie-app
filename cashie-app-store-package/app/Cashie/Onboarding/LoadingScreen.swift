import SwiftUI

struct LoadingScreen: View {
    @EnvironmentObject var container: AppContainer
    @State private var rotation: Double = 0
    @State private var checks: [Bool] = [false, false, false, false]

    private let steps = [
        "Reading your answers",
        "Cross-referencing \(Archetype.totalPopulationLabel) profiles",
        "Identifying your money type",
        "Drafting your action plan"
    ]

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            GoldBlob(alignment: .topTrailing, size: 380, intensity: 0.10).ignoresSafeArea()
            GoldBlob(alignment: .bottomLeading, size: 380, intensity: 0.06).ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()
                Orbit(rotation: rotation)
                    .frame(width: 200, height: 200)
                    .onAppear {
                        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }

                EmphasizedHeadline(
                    raw: "Building your <em>money profile</em>",
                    font: AppFont.display(30, weight: .bold)
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, text in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(checks[i] ? Theme.Palette.gold : Theme.Palette.bgCream)
                                    .frame(width: 22, height: 22)
                                if checks[i] {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Text(text)
                                .font(AppFont.callout)
                                .foregroundColor(checks[i] ? Theme.Palette.ink : Theme.Palette.inkSoft)
                        }
                    }
                }
                .padding(.top, 18)
                .padding(.horizontal, 36)

                Spacer()
            }
            .padding(.bottom, 28)
        }
        .onAppear { run() }
    }

    private func run() {
        Task {
            for i in 0..<checks.count {
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run {
                    withAnimation(Theme.Motion.snap) { checks[i] = true }
                }
            }
            // Hold the completed list for ~3.4s so the user reads the final
            // line and feels the system "thinking" before the big reveal.
            try? await Task.sleep(nanoseconds: 3_400_000_000)
            await MainActor.run { container.advanceOnboarding(to: .reveal) }
        }
    }
}

private struct Orbit: View {
    var rotation: Double

    var body: some View {
        ZStack {
            Circle().stroke(Theme.Palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: 180, height: 180)
            Circle().stroke(Theme.Palette.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: 130, height: 130)

            ForEach(0..<4) { i in
                Circle()
                    .fill(orbitColors[i])
                    .frame(width: 14, height: 14)
                    .offset(x: i % 2 == 0 ? 90 : 65)
                    .rotationEffect(.degrees(rotation + Double(i) * 90))
            }

            CoinMark(size: 84)
        }
    }

    private var orbitColors: [Color] {
        [Theme.Palette.gold, Theme.Palette.ink, Color(hex: 0x1be598), Color(hex: 0xeebf3a)]
    }
}
