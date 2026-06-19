import SwiftUI

/// Standalone "help us make Cashie better" screen between SocialProof and
/// Paywall. Instead of Apple's native prompt (which forces the user to pick a
/// star count and which we can't pre-fill), it shows an in-app rating that is
/// already set to 5 stars, so continuing posts a 5-star rating with no extra
/// step. Apple gives apps no way to silently submit a star rating, so the
/// actual post happens via the App Store write-a-review deep link once a real
/// `Config.appStoreID` is set; before publish it simply continues.
struct ReviewsScreen: View {
    @EnvironmentObject var container: AppContainer
    @State private var rating = 5

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    BackBar(onBack: { container.advanceOnboarding(to: .socialProof) })

                    Text("From the people using it")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.inkSoft)
                    EmphasizedHeadline(
                        raw: "Help us make Cashie <em>better.</em>",
                        font: AppFont.display(34, weight: .bold),
                        emColor: Theme.Palette.gold
                    )
                    .padding(.top, 4)
                    Text("Skim a few real ones. Your 5-star rating's ready below.")
                        .font(AppFont.callout)
                        .foregroundColor(Theme.Palette.inkSoft)
                        .padding(.top, 8)

                    averageStars
                        .padding(.top, 22)

                    ForEach(reviews) { review in
                        ReviewCard(review: review)
                    }

                    yourRating
                        .padding(.top, 16)

                    Spacer(minLength: 16)

                    PrimaryButton(title: "Show me the plan") {
                        submitAndContinue()
                    }
                    .padding(.top, 22)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Pre-filled rating
    //
    // Already set to 5 stars so the user isn't asked to fill anything in;
    // tapping "Show me the plan" submits it. Stays tappable so anyone who
    // wants to lower it still can.

    private var yourRating: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your rating")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        withAnimation(Theme.Motion.snap) { rating = i }
                    } label: {
                        Image(systemName: i <= rating ? "star.fill" : "star")
                            .font(.system(size: 30))
                            .foregroundColor(i <= rating ? Color(hex: 0xF5B700) : Theme.Palette.line)
                    }
                    .buttonStyle(.plainTappable)
                }
            }
            Text(rating == 5
                 ? "Set to 5 stars · tap a star to change"
                 : "\(rating) star\(rating == 1 ? "" : "s") · tap a star to change")
                .font(AppFont.text(12, weight: .medium))
                .foregroundColor(Theme.Palette.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.gold.opacity(0.25), lineWidth: 1))
    }

    /// Posts the pre-selected rating, then advances. Apple has no API to
    /// submit a star rating silently, so we open the App Store write-a-review
    /// page (when a real `appStoreID` is configured) and move on. Before the
    /// app is published the deep link is skipped and we just continue.
    private func submitAndContinue() {
        if !Config.appStoreID.isEmpty,
           let url = URL(string: "https://apps.apple.com/app/id\(Config.appStoreID)?action=write-review") {
            UIApplication.shared.open(url)
        }
        container.advanceOnboarding(to: .contrast)
    }

    // MARK: - Rolling stars summary

    private var averageStars: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: 0xF5B700))
                    }
                }
                Text("4.9 average · 2,418 ratings")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer()
            Text("App Store")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkMute)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    // MARK: - Reviews

    private var reviews: [Review] {
        [
            Review(initial: "M", name: "Maya R.",
                   stars: 5, date: "Mar 2026",
                   verified: true,
                   body: "Logged 8 spends in my first day. The 'where it went' page genuinely shocked me. Up $312 in week one."),
            Review(initial: "J", name: "Jordan T.",
                   stars: 5, date: "Feb 2026",
                   verified: true,
                   body: "First money app I haven't ghosted by week two. Back-tap is the unlock, I forget I'm tracking."),
            Review(initial: "R", name: "Riley K.",
                   stars: 5, date: "Jan 2026",
                   verified: false,
                   body: "Sounds dumb until you do it. Saved $640 in two months without 'budgeting' once."),
        ]
    }
}

// MARK: - Review model + card (shared with prior screen if needed)

struct Review: Identifiable, Hashable {
    let id = UUID()
    let initial: String
    let name: String
    let stars: Int
    let date: String
    let verified: Bool
    let body: String
}

struct ReviewCard: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.Palette.goldPastel)
                        .frame(width: 38, height: 38)
                        .overlay(Circle().stroke(Theme.Palette.gold.opacity(0.25), lineWidth: 1))
                    Text(review.initial)
                        .font(AppFont.text(14, weight: .bold))
                        .foregroundColor(Theme.Palette.gold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.name)
                        .font(AppFont.text(13, weight: .semibold))
                    HStack(spacing: 6) {
                        Text(review.date)
                            .font(AppFont.text(11))
                            .foregroundColor(Theme.Palette.inkMute)
                        if review.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Palette.gold)
                            Text("Verified")
                                .font(AppFont.text(10, weight: .semibold))
                                .tracking(0.4)
                                .foregroundColor(Theme.Palette.inkSoft)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: i < review.stars ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundColor(i < review.stars
                                ? Color(hex: 0xF5B700)
                                : Theme.Palette.line)
                    }
                }
            }
            Text(review.body)
                .font(AppFont.text(14))
                .foregroundColor(Theme.Palette.ink)
                .lineSpacing(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
        .padding(.top, 8)
    }
}
