import SwiftUI

/// Friendly empty-state nudge: a short note and a hand-sketched, dotted arrow
/// that swoops down toward the floating "+" button in the tab bar, the way
/// someone would scribble a pointer on a notepad. Shown when there's nothing
/// logged yet so a fresh account never feels blank or stuck.
struct AddLogNudge: View {
    var message: String = "Tap the + to log your first spend"

    /// Gentle looping bob so the arrow feels alive and draws the eye downward.
    @State private var bob: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .font(AppFont.text(15, weight: .semibold, italic: true))
                .foregroundColor(Theme.Palette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            ZStack {
                SketchArrowShape()
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.4, 9]))
                SketchArrowHead()
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    // Nudge the caret right so it sits under the dotted line's
                    // trailing dots (the curve arrives from the right), instead
                    // of reading slightly left of them.
                    .offset(x: 8)
            }
            .foregroundColor(Theme.Palette.gold.opacity(0.85))
            .frame(width: 150, height: 92)
            .offset(y: bob)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                bob = 7
            }
        }
    }
}

/// A loose, hand-drawn curve sweeping from the upper-left, bulging right, and
/// curling down to a point at the bottom-centre, aimed at the tab-bar "+".
private struct SketchArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.16))
        p.addCurve(
            to: tip,
            control1: CGPoint(x: rect.maxX * 1.05, y: rect.minY - rect.height * 0.05),
            control2: CGPoint(x: rect.maxX * 0.74, y: rect.maxY * 0.94)
        )
        return p
    }
}

/// The two short strokes of the arrowhead, sharing the curve's bottom-centre
/// tip so they meet cleanly and point straight down.
private struct SketchArrowHead: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        p.move(to: CGPoint(x: tip.x - 10, y: tip.y - 13))
        p.addLine(to: tip)
        p.addLine(to: CGPoint(x: tip.x + 12, y: tip.y - 9))
        return p
    }
}
