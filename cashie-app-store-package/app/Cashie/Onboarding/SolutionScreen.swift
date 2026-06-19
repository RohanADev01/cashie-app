import SwiftUI

struct SolutionScreen: View {
    @EnvironmentObject var container: AppContainer

    private let rows: [(emoji: String, title: String, body: String)] = [
        ("🎯", "See the leak, named",
         "Specific categories, times, moments. Not 'misc.'"),
        ("⚡", "2-second Quick Log",
         "Tap the back of your phone twice. Done."),
        ("🚨", "Impulse circuit-breaker",
         "10-second pause before the buys you regret."),
        ("💳", "Safe to spend, live",
         "Pre-loaded with bills + goals. Just one number."),
    ]

    var body: some View {
        baseBody.tapAnywhereToContinue { container.advanceOnboarding(to: .socialProof) }
    }

    private var baseBody: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                BackBar(onBack: { container.advanceOnboarding(to: .pain) },
                        pageLabel: "Profile · 04 / 05")

                Text("The fix")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)

                EmphasizedHeadline(
                    raw: "Four moves. <em>One app.</em>",
                    font: AppFont.display(34, weight: .bold)
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(rows, id: \.title) { row in
                            HStack(alignment: .top, spacing: 14) {
                                Text(row.emoji)
                                    .font(.system(size: 22))
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(Theme.Palette.goldPastel))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.title)
                                        .font(AppFont.title3)
                                        .foregroundColor(Theme.Palette.ink)
                                    Text(row.body)
                                        .font(AppFont.callout)
                                        .foregroundColor(Theme.Palette.inkSoft)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.top, 16)
                }

                PrimaryButton(title: "What's that worth?") {
                    container.advanceOnboarding(to: .socialProof)
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
        }
    }
}
