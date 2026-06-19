import SwiftUI

struct ReadyScreen: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var state: OnboardingState

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ConfettiBackground()

            VStack(spacing: 14) {
                Text("YOU'RE READY")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(4)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .padding(.top, 8)

                ZStack {
                    Circle().fill(Theme.Palette.goldPastel).frame(width: 90, height: 90)
                    Text("🎉").font(.system(size: 40))
                }
                .padding(.top, 18)

                EmphasizedHeadline(
                    raw: "<em>That's it.</em> Take a look.",
                    font: AppFont.display(40, weight: .bold)
                )

                VStack(spacing: 6) {
                    item("Money type: \(state.selectedArchetype.name)")
                    item("Permissions configured")
                    item("Quick Log: live on your device")
                    item("First log: \(Money.symbol)18 food saved")
                }
                .padding(.top, 18)

                hint
                    .padding(.top, 14)

                Spacer()

                PrimaryButton(title: "Open Cashie") {
                    container.user.archetype = state.selectedArchetype
                    container.user.traits = state.traits
                    container.goToMain()
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 70)
            .padding(.bottom, 28)
        }
    }

    private func item(_ text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.Palette.gold).frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(text)
                .font(AppFont.text(13, weight: .medium))
                .foregroundColor(Theme.Palette.ink)
            Spacer()
        }
    }

    private var hint: some View {
        HStack(spacing: 12) {
            Text("💡").font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text("Try it now")
                    .font(AppFont.text(13, weight: .semibold))
                Text("Triple-tap the back of your phone, Quick Log should pop up.")
                    .font(AppFont.text(13))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Palette.gold.opacity(0.3), lineWidth: 1))
    }
}
