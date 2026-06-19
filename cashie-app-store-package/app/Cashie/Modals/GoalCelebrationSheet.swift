import SwiftUI

/// Surfaced the moment a deposit pushes a goal past its target. Shown once;
/// the action button moves the goal into Past wins so it stops cluttering
/// the active list.
struct GoalCelebrationSheet: View {
    let goal: Goal
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    @State private var burstScale: CGFloat = 0.5
    @State private var burstOpacity: Double = 0
    @State private var emojiBob: CGFloat = 0
    @State private var ringScale: CGFloat = 0.8

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Palette.winGoldPastel, Color.white],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                trophy
                copy
                actions
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .onAppear { runIntro() }
    }

    private var trophy: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Capsule()
                    .fill(rayColor(i))
                    .frame(width: 4, height: 70)
                    .offset(y: -52)
                    .rotationEffect(.degrees(Double(i) * 60))
                    .scaleEffect(burstScale)
                    .opacity(burstOpacity)
            }
            Circle()
                .fill(Theme.Palette.winGoldGradient)
                .frame(width: 110, height: 110)
                .scaleEffect(ringScale)
                .shadow(color: Theme.Palette.winGold.opacity(0.45), radius: 18, y: 8)
            Text(goal.emoji)
                .font(.system(size: 56))
                .offset(y: emojiBob)
        }
        .frame(height: 160)
    }

    private func rayColor(_ i: Int) -> Color {
        let palette: [Color] = [
            Theme.Palette.winGold,
            Color(hex: 0xE5B860),
            Color(hex: 0xB07A1F),
            Theme.Palette.winGoldLight,
        ]
        return palette[i % palette.count]
    }

    private var copy: some View {
        VStack(spacing: 8) {
            Text("Funded.")
                .font(AppFont.display(40, weight: .heavy))
                .foregroundColor(Theme.Palette.ink)
            Text("\(goal.name) · \(Money.format(goal.targetAmount))")
                .font(AppFont.text(15, weight: .semibold))
                .foregroundColor(Theme.Palette.ink)
            Text(footnote)
                .font(AppFont.callout)
                .foregroundColor(Theme.Palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
        }
    }

    private var footnote: String {
        let count = max(1, goal.deposits.count)
        let depositsLabel = count == 1 ? "1 deposit" : "\(count) deposits"
        return "Done in \(depositsLabel). Filed under Past wins so the active list stays clean."
    }

    private var actions: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Move to Past wins", trailingArrow: false) {
                container.archiveGoal(goal.id)
                dismiss()
            }
            Button("Keep it active for now") {
                dismiss()
            }
            .font(AppFont.text(13, weight: .semibold))
            .foregroundColor(Theme.Palette.inkSoft)
            .padding(.vertical, 4)
        }
    }

    private func runIntro() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
            ringScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.05)) {
            burstScale = 1.2
            burstOpacity = 1
        }
        withAnimation(.easeIn(duration: 0.7).delay(0.55)) {
            burstOpacity = 0
        }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            emojiBob = -6
        }
    }
}
