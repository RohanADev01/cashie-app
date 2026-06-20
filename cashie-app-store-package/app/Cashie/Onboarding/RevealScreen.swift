import SwiftUI

struct RevealScreen: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var state: OnboardingState

    /// Reveal beats. Each step unhides the next chunk. Holding rows in the
    /// container from the start (with opacity/offset gates) keeps the layout
    /// stable — only opacity/offset animate, no jumpy reflows.
    @State private var step: Int = 0

    private enum Beat: Int {
        case foundEyebrow = 1
        case nameHeadline = 2
        case badge = 3
        case tagline = 4
        case statsCard = 5   // the whole results table reveals together
        case cta = 6
    }

    // No tap-anywhere here: the reveal is a deliberate moment and stray taps
    // were causing trouble, so only the explicit CTA advances.
    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            GoldBlob(alignment: .topTrailing, size: 280, intensity: 0.06)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    foundEyebrow
                        .padding(.bottom, 6)
                        .opacity(reached(.foundEyebrow) ? 1 : 0)
                        .scaleEffect(reached(.foundEyebrow) ? 1 : 0.85)
                        .offset(y: reached(.foundEyebrow) ? 0 : 12)

                    nameHeadline
                        .padding(.top, 10)
                        .opacity(reached(.nameHeadline) ? 1 : 0)
                        .scaleEffect(reached(.nameHeadline) ? 1 : 0.92)
                        .offset(y: reached(.nameHeadline) ? 0 : 16)

                    badge
                        .padding(.vertical, 5)
                        .scaleEffect(reached(.badge) ? 1 : 0.5)
                        .opacity(reached(.badge) ? 1 : 0)

                    tagline
                        .padding(.horizontal, 26)
                        .padding(.top, 6)
                        .opacity(reached(.tagline) ? 1 : 0)
                        .offset(y: reached(.tagline) ? 0 : 10)

                    insights
                        .padding(.top, 18)
                        .opacity(reached(.statsCard) ? 1 : 0)
                        .scaleEffect(reached(.statsCard) ? 1 : 0.97)
                        .offset(y: reached(.statsCard) ? 0 : 14)

                    PrimaryButton(title: "See my profile in detail") {
                        container.advanceOnboarding(to: .traits)
                    }
                    .padding(.top, 22)
                    .opacity(reached(.cta) ? 1 : 0)
                    .offset(y: reached(.cta) ? 0 : 16)
                    .disabled(!reached(.cta))
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 28)
            }

            // Confetti kicks in with the celebratory eyebrow. ConfettiBackground
            // stabilises its pieces internally so it won't re-spawn on re-renders.
            if reached(.foundEyebrow) {
                ConfettiBackground(style: .celebration)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear { runReveal() }
    }

    // MARK: Pieces

    private var foundEyebrow: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .heavy))
            Text("WE'VE FOUND YOUR PROFILE!")
                .font(AppFont.text(12, weight: .heavy))
                .tracking(1.8)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.Palette.green))
        .shadow(color: Theme.Palette.green.opacity(0.35), radius: 14, x: 0, y: 6)
    }

    private var nameHeadline: some View {
        EmphasizedHeadline(
            raw: "Meet\n<em>\(state.selectedArchetype.name).</em>",
            font: AppFont.display(36, weight: .bold)
        )
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
    }

    private var badge: some View {
        ArchetypeBadge(emoji: state.selectedArchetype.emoji, size: 130)
    }

    private var tagline: some View {
        Text(state.selectedArchetype.tagline)
            .font(AppFont.text(14, weight: .regular, italic: true))
            .foregroundColor(Theme.Palette.inkSoft)
            .multilineTextAlignment(.center)
    }

    /// The results table, revealed all together with the `statsCard` beat (the
    /// parent gates its opacity/scale). Uses the shared `ArchetypeQuickStats`
    /// soft-card tiles so the reveal matches the new main-screen UI.
    private var insights: some View {
        ArchetypeQuickStats(archetype: state.selectedArchetype)
    }

    // MARK: Driver

    private func reached(_ beat: Beat) -> Bool { step >= beat.rawValue }

    private func runReveal() {
        Task {
            // (delayBeforeBeat, beat, animation)
            let beats: [(Double, Beat, Animation)] = [
                (0.20, .foundEyebrow, .spring(response: 0.55, dampingFraction: 0.62)),
                (0.95, .nameHeadline, .spring(response: 0.55, dampingFraction: 0.78)),
                (0.55, .badge, .spring(response: 0.55, dampingFraction: 0.55)),
                (0.55, .tagline, .spring(response: 0.55, dampingFraction: 0.85)),
                (0.70, .statsCard, .spring(response: 0.55, dampingFraction: 0.85)),
                (0.65, .cta, .spring(response: 0.55, dampingFraction: 0.82)),
            ]
            for entry in beats {
                try? await Task.sleep(nanoseconds: UInt64(entry.0 * 1_000_000_000))
                await MainActor.run {
                    withAnimation(entry.2) {
                        step = entry.1.rawValue
                    }
                }
            }
        }
    }
}
