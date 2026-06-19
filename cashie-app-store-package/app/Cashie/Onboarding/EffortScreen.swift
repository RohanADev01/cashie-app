import SwiftUI

struct EffortScreen: View {
    @EnvironmentObject var container: AppContainer

    private let rows: [(tag: String, body: String, highlight: Bool)] = [
        ("20 sec", "Map the back-tap to Quick Log.", false),
        ("2 sec", "Apple Pay shortcut auto-fills the amount.", false),
        ("30 sec", "Set a goal you'd actually like.", false),
        ("Done", "No bank linking. No spreadsheets. No guilt.", true),
    ]

    var body: some View {
        baseBody.tapAnywhereToContinue { container.advanceOnboarding(to: .permissions) }
    }

    private var baseBody: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                BackBar(onBack: { container.advanceOnboarding(to: .nameInput) },
                        pageLabel: "Setup · 00 / 03")

                Text("And now, the easy part")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)

                EmphasizedHeadline(
                    raw: "Hard part's done. <em>Now, one minute.</em>",
                    font: AppFont.display(34, weight: .bold)
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(rows, id: \.body) { row in
                            HStack(alignment: .top, spacing: 14) {
                                Text(row.tag)
                                    .font(AppFont.text(10, weight: .bold))
                                    .tracking(1)
                                    .textCase(.uppercase)
                                    .foregroundColor(row.highlight ? .white : Theme.Palette.ink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(row.highlight ? Theme.Palette.gold : Theme.Palette.bgCream)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(row.highlight ? Theme.Palette.gold : Theme.Palette.line, lineWidth: 1)
                                    )
                                Text(row.body)
                                    .font(AppFont.callout)
                                    .foregroundColor(Theme.Palette.ink)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(row.highlight ? Theme.Palette.goldPastel : Color.clear)
                            )
                        }
                    }
                    .padding(.top, 18)
                }

                PrimaryButton(title: "Let’s set it up") {
                    container.advanceOnboarding(to: .permissions)
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
        }
    }
}
