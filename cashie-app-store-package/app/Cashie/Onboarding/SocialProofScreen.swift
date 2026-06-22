import SwiftUI

/// Merged "Future" screen: graph (top) + two-column WITHOUT/WITH comparison
/// (bottom). Does the job of both the old SocialProof and Contrast screens in
/// one pass, then sends the user straight to the paywall.
struct SocialProofScreen: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var state: OnboardingState
    @State private var chartProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    BackBar(onBack: { container.advanceOnboarding(to: .quickLogIntro) })

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
                    Text("Small daily decisions compound faster than most people expect.")
                        .font(AppFont.callout)
                        .foregroundColor(Theme.Palette.inkSoft)
                        .padding(.top, 8)

                    chartCard.padding(.top, 22)

                    comparisonBlock.padding(.top, 24)

                    PrimaryButton(title: "Show me the plan") {
                        container.advanceOnboarding(to: .paywall)
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
                LegendDot(color: Theme.Palette.red, label: "Without Cashie")
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

    // MARK: - WITHOUT / WITH comparison

    private var comparisonBlock: some View {
        HStack(alignment: .top, spacing: 14) {
            comparisonColumn(
                heading: "Keep going the same way",
                icon: "xmark.circle.fill",
                iconColor: Theme.Palette.red,
                lines: [
                    "Payday disappears fast",
                    "Balance checks feel stressful",
                    "Unsure where the money went"
                ]
            )
            comparisonColumn(
                heading: "Start tracking",
                icon: "checkmark.circle.fill",
                iconColor: Theme.Palette.green,
                lines: [
                    "Know what's safe to spend",
                    "Reach payday with money left",
                    "See spending clearly"
                ]
            )
        }
    }

    private func comparisonColumn(heading: String, icon: String,
                                  iconColor: Color, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heading)
                .font(AppFont.text(12, weight: .heavy))
                .foregroundColor(Theme.Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(iconColor)
                        .padding(.top, 2)
                    Text(line)
                        .font(AppFont.text(13, weight: .medium))
                        .foregroundColor(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Chart pieces

struct MascotLegend: View {
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Image("Mascot")
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
            Text(label)
                .font(AppFont.text(11, weight: .semibold))
                .foregroundColor(Theme.Palette.inkSoft)
        }
    }
}

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

struct GrowthChart: View {
    let progress: CGFloat

    private let redYs: [CGFloat]   = [0.10, 0.06, 0.20, 0.34, 0.50,
                                      0.66, 0.58, 0.74, 0.66, 0.82, 0.74, 0.90]
    private let greenYs: [CGFloat] = [0.92, 0.96, 0.82, 0.66, 0.50,
                                      0.34, 0.42, 0.26, 0.34, 0.18, 0.26, 0.10]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let pad: CGFloat = 8
            let redPts = points(for: redYs, width: w, height: h, pad: pad)
            let greenPts = points(for: greenYs, width: w, height: h, pad: pad)

            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h / 2))
                    p.addLine(to: CGPoint(x: w, y: h / 2))
                }
                .stroke(Theme.Palette.line, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                lineLayer(points: redPts, color: Theme.Palette.red,
                          width: w, height: h, progress: progress)

                lineLayer(points: greenPts, color: Theme.Palette.gold,
                          width: w, height: h, progress: progress)

                if progress > 0.95 {
                    Text("🥡")
                        .font(.system(size: 26))
                        .shadow(color: Theme.Palette.red.opacity(0.4), radius: 6)
                        .position(redPts.last ?? CGPoint(x: w, y: h - pad))
                        .transition(.scale.combined(with: .opacity))
                    Text("💰")
                        .font(.system(size: 26))
                        .shadow(color: Theme.Palette.gold.opacity(0.5), radius: 6)
                        .position(greenPts.last ?? CGPoint(x: w, y: pad))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    @ViewBuilder
    private func lineLayer(points: [CGPoint], color: Color,
                           width w: CGFloat, height h: CGFloat,
                           progress: CGFloat,
                           lineWidth: CGFloat = 3,
                           fillOpacity: CGFloat = 0.28) -> some View {
        let line = smoothPath(points: points)
        let area = areaPath(points: points, width: w, height: h)

        area
            .fill(
                LinearGradient(
                    colors: [color.opacity(fillOpacity), color.opacity(0.0)],
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
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
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
