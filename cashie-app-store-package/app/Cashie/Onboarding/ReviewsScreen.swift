import SwiftUI

/// A minimal rating ask shown between SocialProof and Paywall, styled like the
/// feature tour: one centered visual (five stars) under a short headline.
///
/// We deep-link to the App Store write-review URL rather than calling Apple's
/// in-app `requestReview`, because `requestReview` is a silent no-op in
/// TestFlight (Apple disables it there) and is also rate-limited to ~3 shows
/// per 365 days on App Store builds, with no callback either way. The deep
/// link works in every build and never lies about what just happened.
struct ReviewsScreen: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
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
                    Text("Tap the stars to rate Cashie on the App Store. It takes a second and really helps.")
                        .font(AppFont.callout)
                        .foregroundColor(Theme.Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 8)

                PrimaryButton(title: "Rate Cashie") { rate() }
                    .padding(.horizontal, 28)
                    .padding(.top, 6)

                GhostButton(title: "Not now") {
                    container.advanceOnboarding(to: .contrast)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
            }
            .padding(.top, 8)
        }
    }

    /// Five large, tappable stars. Tapping any of them opens the App Store
    /// write-review URL, same as the primary button.
    private var stars: some View {
        HStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { _ in
                Button { rate() } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(Color(hex: 0xF5B700))
                }
                .buttonStyle(.plainTappable)
            }
        }
    }

    /// Opens the App Store write-review URL (if we have the numeric Apple ID)
    /// and advances to the next onboarding step. The advance happens whether
    /// or not the link opens, so an empty `appStoreID` doesn't trap the user.
    private func rate() {
        let id = Config.appStoreID
        if !id.isEmpty,
           let url = URL(string: "https://apps.apple.com/app/id\(id)?action=write-review") {
            UIApplication.shared.open(url)
        }
        container.advanceOnboarding(to: .contrast)
    }
}
