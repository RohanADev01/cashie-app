import SwiftUI
import StoreKit

/// A minimal rating ask shown between SocialProof and Paywall, styled like the
/// feature tour: one centered visual (five stars) under a short headline.
///
/// Apple's in-app rating prompt (`requestReview`) is fire-and-forget: it has no
/// completion callback, so we can't know whether the user rated or tapped "Not
/// Now", and iOS rate-limits it (~3x/year) so it may not appear at all.
///
/// Because of that, tapping a star or "Rate Cashie" only *opens* the prompt; it
/// does NOT advance. Once the prompt has been requested the CTA turns into
/// "Continue", so moving on is always a separate, explicit tap the user makes
/// after they've dealt with (or dismissed) the rating modal. Full-screen
/// tap-to-continue is off here so a stray tap can't skip past the rating.
struct ReviewsScreen: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.requestReview) private var requestReview

    /// Set once the native prompt has been requested. Flips the CTA from
    /// "Rate Cashie" (opens the prompt) to "Continue" (advances).
    @State private var hasRequested = false

    var body: some View {
        baseBody
    }

    private var baseBody: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            GoldBlob(alignment: .topTrailing, size: 360, intensity: 0.10).ignoresSafeArea()

            VStack(spacing: 0) {
                BackBar(onBack: { container.advanceOnboarding(to: .socialProof) })
                    .padding(.horizontal, 26)

                Spacer(minLength: 8)

                stars
                    .frame(height: 280)

                Spacer(minLength: 16)

                VStack(spacing: 12) {
                    Text("Enjoying Cashie?")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.gold)
                    EmphasizedHeadline(
                        raw: "Help us with a <em>quick rating</em>.",
                        font: AppFont.display(38, weight: .bold)
                    )
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    Text(supportingText)
                        .font(AppFont.callout)
                        .foregroundColor(Theme.Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 8)

                PrimaryButton(title: hasRequested ? "Continue" : "Rate Cashie") {
                    if hasRequested {
                        advance()
                    } else {
                        requestRating()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
    }

    private var supportingText: String {
        hasRequested
            ? "Thanks for the love! Tap continue when you're ready."
            : "Tap the stars to rate Cashie on the App Store. It takes a second and really helps."
    }

    /// Five large, tappable stars. Tapping any of them opens Apple's native
    /// rating prompt (same as the button); it does not advance on its own.
    private var stars: some View {
        HStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { _ in
                Button { requestRating() } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(Color(hex: 0xF5B700))
                }
                .buttonStyle(.plainTappable)
            }
        }
    }

    /// Opens Apple's native in-app rating prompt and flips the CTA to "Continue".
    /// We never auto-advance: the prompt has no callback, so the user moves on
    /// themselves once they've rated or dismissed it. iOS may suppress the prompt
    /// (rate-limited), in which case the CTA still becomes "Continue" so the user
    /// is never stuck.
    private func requestRating() {
        requestReview()
        withAnimation(Theme.Motion.snap) { hasRequested = true }
    }

    private func advance() {
        container.advanceOnboarding(to: .contrast)
    }
}
