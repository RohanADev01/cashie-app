import SwiftUI

/// Standalone "two ways this goes" beat between Reviews and Paywall.
/// Lets the user flip between the WITHOUT (current pain) and WITH (relief)
/// framing as a final emotional preview before they see pricing.
struct ContrastScreen: View {
    @EnvironmentObject var container: AppContainer
    @State private var stage: PaywallStage = .without
    @State private var bob: CGFloat = 0
    @State private var tilt: Double = -3

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    BackBar(onBack: { container.advanceOnboarding(to: .reviews) })

                    Text("Two ways this goes")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.inkSoft)

                    EmphasizedHeadline(
                        raw: "Pick the <em>life</em> you want.",
                        font: AppFont.display(34, weight: .bold)
                    )

                    Text("Tap WITH to see the glow up.")
                        .font(AppFont.callout)
                        .foregroundColor(Theme.Palette.inkSoft)

                    contrastCard

                    Spacer(minLength: 8)

                    PrimaryButton(title: "I'm ready") {
                        container.advanceOnboarding(to: .paywall)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
            }
        }
    }

    // MARK: - Contrast card (toggle + bullets + delta)

    private var contrastCard: some View {
        VStack(spacing: 0) {
            stageToggle
            VStack(alignment: .leading, spacing: 12) {
                Text(stage == .without ? "Always low-key broke" : "Finally chill")
                    .font(AppFont.display(28, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)

                bullets

                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 1)
                    .padding(.vertical, 2)

                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stage == .without ? "RIGHT NOW" : "WITH CASHIE")
                            .font(AppFont.text(10, weight: .heavy))
                            .tracking(1.4)
                            .foregroundColor(.white.opacity(0.6))
                        // Qualitative outcome, not a promised dollar figure.
                        Text(stage == .without ? "Money runs you" : "You run your money")
                            .font(AppFont.display(30, weight: .heavy))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Spacer()
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(stage)
            .transition(.opacity)
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(stageGradient))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: stageBase.opacity(0.35), radius: 22, x: 0, y: 14)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture { toggleStage() }
        .animation(.easeInOut(duration: 0.4), value: stage)
    }

    private var stageToggle: some View {
        HStack(spacing: 4) {
            stagePill(.without, label: "WITHOUT")
            stagePill(.with, label: "WITH")
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.25)))
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        .padding(.top, 14)
        .padding(.horizontal, 14)
    }

    private func stagePill(_ s: PaywallStage, label: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { stage = s }
        }) {
            Text(label)
                .font(AppFont.text(11, weight: .heavy))
                .tracking(1.2)
                .foregroundColor(stage == s ? .black : .white.opacity(0.78))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Capsule().fill(stage == s ? Color.white : Color.clear))
        }
        .buttonStyle(.plainTappable)
    }

    private func toggleStage() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            stage = (stage == .without) ? .with : .without
        }
    }

    private var stageBase: Color {
        stage == .without ? Theme.Palette.red : Theme.Palette.green
    }

    private var stageGradient: LinearGradient {
        let dark = stage == .without
            ? Color(hex: 0x8B1F1F)
            : Color(hex: 0x025A38)
        return LinearGradient(colors: [stageBase, dark],
                              startPoint: .top, endPoint: .bottom)
    }

    private var stageAccent: Color {
        stage == .without ? Color(hex: 0xFFD9D4) : Color(hex: 0xCFFBE2)
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(currentLines, id: \.self) { line in
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: stage == .with ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(stageAccent)
                        .padding(.top, 2)
                    Text(line)
                        .font(AppFont.text(15.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var currentLines: [String] {
        stage == .without
        ? [
            "Too scared to check my balance",
            "Payday money gone by the weekend",
            "No clue where it actually went"
          ]
        : [
            "I check my balance, zero panic",
            "My money actually makes it to payday",
            "I know where every dollar goes"
          ]
    }
}
