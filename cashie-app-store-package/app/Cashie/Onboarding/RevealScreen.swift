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
        case statsCard = 5
        case stat1 = 6
        case stat2 = 7
        case stat3 = 8
        case cta = 9
    }

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

    private var insights: some View {
        VStack(spacing: 0) {
            Text("Quick stats")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            statRow(beat: .stat1,
                    label: "Confidence in match",
                    value: "\(state.selectedArchetype.matchPercent)%")
            dividerRow(beat: .stat1, nextBeat: .stat2)
            statRow(beat: .stat2,
                    label: "Estimated $/year leak",
                    value: Money.format(state.selectedArchetype.painYearly))
            dividerRow(beat: .stat2, nextBeat: .stat3)
            statRow(beat: .stat3,
                    label: "Others like you we've seen",
                    value: state.selectedArchetype.populationLabel,
                    avatars: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Palette.bgCream)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Palette.line, lineWidth: 1)
        )
    }

    private func statRow(beat: Beat, label: String, value: String, avatars: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(AppFont.callout)
                .foregroundColor(Theme.Palette.ink)
            Spacer()
            if avatars {
                HStack(spacing: 8) {
                    AvatarStack(size: 26, overlap: 9)
                    Text(value)
                        .font(AppFont.text(16, weight: .semibold))
                        .foregroundColor(Theme.Palette.ink)
                }
            } else {
                Text(value)
                    .font(AppFont.text(16, weight: .semibold))
                    .foregroundColor(Theme.Palette.ink)
            }
        }
        .padding(.vertical, 10)
        .opacity(reached(beat) ? 1 : 0)
        .offset(x: reached(beat) ? 0 : 20)
    }

    private func dividerRow(beat: Beat, nextBeat: Beat) -> some View {
        Rectangle()
            .fill(Theme.Palette.lineSoft)
            .frame(height: 1)
            .opacity(reached(nextBeat) ? 1 : 0)
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
                (0.55, .stat1, .spring(response: 0.50, dampingFraction: 0.78)),
                (0.45, .stat2, .spring(response: 0.50, dampingFraction: 0.78)),
                (0.45, .stat3, .spring(response: 0.50, dampingFraction: 0.78)),
                (0.55, .cta, .spring(response: 0.55, dampingFraction: 0.82)),
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
