import SwiftUI

struct SocialProofScreen: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var state: OnboardingState
    @State private var chartProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    BackBar(onBack: { container.advanceOnboarding(to: .solution) })

                    Text("12 months later")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.inkSoft)
                    EmphasizedHeadline(
                        raw: "Two paths, <em>one choice.</em>",
                        font: AppFont.display(36, weight: .bold),
                        emColor: Theme.Palette.gold
                    )
                    .padding(.top, 4)
                    Text("\(state.selectedArchetype.populationLabel) others like you tracked over a year. Same income. Different outcome.")
                        .font(AppFont.callout)
                        .foregroundColor(Theme.Palette.inkSoft)
                        .padding(.top, 8)

                    chartCard.padding(.top, 22)

                    Spacer(minLength: 28)

                    PrimaryButton(title: "Show me the plan") {
                        container.advanceOnboarding(to: .reviews)
                    }
                    .padding(.top, 28)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).delay(0.1)) { chartProgress = 1 }
        }
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                LegendDot(color: Theme.Palette.gold, label: "With Cashie")
                LegendDot(color: Theme.Palette.red, label: "Without")
                Spacer()
            }
            GrowthChart(progress: chartProgress)
                .frame(height: 200)
            HStack {
                Text("MONTH 1")
                Spacer()
                Text("MONTH 12")
            }
            .font(AppFont.text(10, weight: .semibold))
            .tracking(1)
            .foregroundColor(Theme.Palette.inkMute)
        }
    }
}

// MARK: - Chart pieces

struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(AppFont.text(11, weight: .semibold))
                .foregroundColor(Theme.Palette.inkSoft)
        }
    }
}

/// Two natural-looking 12-month lines with a soft gradient fill underneath
/// that wipes in left-to-right alongside the line draw.
struct GrowthChart: View {
    let progress: CGFloat

    // Normalised y per month (0 = top, 1 = bottom). Twelve points each.
    private let redYs: [CGFloat]   = [0.10, 0.18, 0.12, 0.28, 0.22, 0.40,
                                      0.34, 0.52, 0.46, 0.66, 0.78, 0.92]
    private let greenYs: [CGFloat] = [0.92, 0.85, 0.90, 0.72, 0.78, 0.60,
                                      0.64, 0.46, 0.50, 0.30, 0.22, 0.08]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let pad: CGFloat = 8
            let redPts = points(for: redYs, width: w, height: h, pad: pad)
            let greenPts = points(for: greenYs, width: w, height: h, pad: pad)

            ZStack {
                // Faint axis line through the middle
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h / 2))
                    p.addLine(to: CGPoint(x: w, y: h / 2))
                }
                .stroke(Theme.Palette.line, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                // Red - line + soft fill
                lineLayer(points: redPts, color: Theme.Palette.red,
                          width: w, height: h, progress: progress)

                // Green - line + soft fill
                lineLayer(points: greenPts, color: Theme.Palette.gold,
                          width: w, height: h, progress: progress)

                // End dots fade in at the end of the draw
                if progress > 0.95 {
                    Circle().fill(Theme.Palette.red).frame(width: 9, height: 9)
                        .position(redPts.last ?? CGPoint(x: w, y: h - pad))
                    Circle().fill(Theme.Palette.gold).frame(width: 9, height: 9)
                        .shadow(color: Theme.Palette.gold.opacity(0.5), radius: 4)
                        .position(greenPts.last ?? CGPoint(x: w, y: pad))
                }
            }
        }
    }

    @ViewBuilder
    private func lineLayer(points: [CGPoint], color: Color,
                           width w: CGFloat, height h: CGFloat,
                           progress: CGFloat) -> some View {
        let line = smoothPath(points: points)
        let area = areaPath(points: points, width: w, height: h)

        // Soft gradient under the line, masked left-to-right by progress.
        area
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.28), color.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .mask(
                Rectangle()
                    .frame(width: w * progress, height: h)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            )

        line
            .trim(from: 0, to: progress)
            .stroke(color,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }

    private func points(for ys: [CGFloat], width w: CGFloat,
                        height h: CGFloat, pad: CGFloat) -> [CGPoint] {
        guard ys.count > 1 else { return [] }
        let usableH = h - pad * 2
        let step = w / CGFloat(ys.count - 1)
        return ys.enumerated().map { i, y in
            CGPoint(x: CGFloat(i) * step, y: pad + y * usableH)
        }
    }

    /// Catmull-Rom-ish smoothing through the points.
    private func smoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        for i in 1..<points.count {
            let p0 = points[max(0, i - 2)]
            let p1 = points[i - 1]
            let p2 = points[i]
            let p3 = points[min(points.count - 1, i + 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                             y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                             y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    /// Closed area under the line, anchored to the bottom edge.
    private func areaPath(points: [CGPoint], width w: CGFloat,
                          height h: CGFloat) -> Path {
        var path = smoothPath(points: points)
        guard let last = points.last, let first = points.first else { return path }
        path.addLine(to: CGPoint(x: last.x, y: h))
        path.addLine(to: CGPoint(x: first.x, y: h))
        path.closeSubpath()
        return path
    }
}
