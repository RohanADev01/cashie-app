import SwiftUI

/// Shared screen body used by Back Tap and Action Button setup ,
/// they only differ by copy + deep link target.
struct GuidedSetupScreen: View {
    let pageLabel: String
    let kicker: String
    let title: String
    let steps: [(icon: String, title: String, body: String)]
    let primaryTitle: String
    let primaryURL: URL?
    let onContinue: () -> Void
    let onBack: () -> Void
    let secondary: (label: String, action: () -> Void)?
    /// Optional content shown above the numbered steps (e.g. the API key card).
    var accessory: AnyView? = nil
    /// SF Symbol for the primary (open-app) button. Defaults to a gear.
    var primaryIcon: String = "gearshape.fill"

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            // BackBar pinned for navigation; the header + key card + steps scroll
            // together (so they stay readable), while the action buttons stay
            // pinned in a footer so Continue is always reachable.
            VStack(spacing: 0) {
                BackBar(onBack: onBack, pageLabel: pageLabel)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(kicker)
                            .font(AppFont.text(11, weight: .semibold))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(Theme.Palette.inkSoft)

                        EmphasizedHeadline(
                            raw: title,
                            font: AppFont.display(36, weight: .bold)
                        )

                        if let accessory { accessory }

                        VStack(spacing: 12) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: step.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Theme.Palette.gold)
                                        .frame(width: 28, height: 28)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.Palette.goldLight))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step.title)
                                            .font(AppFont.title3)
                                        Text(step.body)
                                            .font(AppFont.text(13))
                                            .foregroundColor(Theme.Palette.inkSoft)
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
                            }
                        }

                        if let url = primaryURL {
                            PrimaryButton(title: primaryTitle, systemImage: primaryIcon, trailingArrow: false) {
                                UIApplication.shared.open(url)
                            }
                            .padding(.top, 4)
                        }

                        PrimaryButton(title: "I've set it up · Continue") {
                            onContinue()
                        }

                        if let s = secondary {
                            Button(s.label, action: s.action)
                                .font(AppFont.text(12, weight: .medium))
                                .foregroundColor(Theme.Palette.gold)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 6)
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
        }
    }
}

struct BackTapSetupScreen: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        GuidedSetupScreen(
            pageLabel: "Quick Log · Back Tap",
            kicker: "iPhone 8–14",
            title: "Map your <em>Back Tap</em> in 20 seconds.",
            steps: [
                ("gearshape.fill", "Settings → Accessibility",
                 "Find 'Touch', then tap 'Back Tap'."),
                ("hand.tap.fill", "Pick Triple Tap",
                 "The triple-tap option works best."),
                ("checkmark.circle.fill", "Choose 'Cashie Quick Log'",
                 "The shortcut you imported appears in the list."),
            ],
            primaryTitle: "Open Settings",
            primaryURL: URL(string: "App-prefs:ACCESSIBILITY"),
            onContinue: { container.advanceOnboarding(to: .currency) },
            onBack: { container.advanceOnboarding(to: .backTapTeaser) },
            secondary: ("My phone has the Action Button, switch", {
                container.advanceOnboarding(to: .actionButtonSetup)
            }),
            accessory: AnyView(QuickLogKeyCard())
        )
    }
}

struct ActionButtonSetupScreen: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        GuidedSetupScreen(
            pageLabel: "Quick Log · Action Button",
            kicker: "iPhone 15 Pro+",
            title: "Map your <em>Action Button</em> in 20 seconds.",
            steps: [
                ("gearshape.fill", "Settings → Action Button",
                 "Side button, just above volume."),
                ("hand.draw.fill", "Swipe to Shortcut",
                 "Pick the Shortcut tile."),
                ("checkmark.circle.fill", "Choose 'Cashie Quick Log'",
                 "The shortcut you imported. Hit done, you're set."),
            ],
            primaryTitle: "Open Settings",
            primaryURL: URL(string: "App-prefs:root=ACCESSIBILITY"),
            onContinue: { container.advanceOnboarding(to: .currency) },
            onBack: { container.advanceOnboarding(to: .backTapTeaser) },
            secondary: ("Use Back Tap instead", {
                container.advanceOnboarding(to: .backTapSetup)
            }),
            accessory: AnyView(QuickLogKeyCard())
        )
    }
}

struct ApplePaySetupScreen: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        GuidedSetupScreen(
            pageLabel: "Quick Log · Apple Pay",
            kicker: "Wallet automation",
            title: "Log <em>after Apple Pay</em> automatically.",
            steps: [
                ("square.grid.2x2.fill", "Open Shortcuts",
                 "Go to the Automation tab."),
                ("plus.circle.fill", "Create Personal Automation",
                 "Tap +, then Create Personal Automation."),
                ("creditcard.fill", "Select Wallet",
                 "Pick your card, then choose 'Cashie Apple Pay Log' to run."),
                ("checkmark.seal.fill", "Run After Confirmation",
                 "Leave this on for your first payment."),
                ("bolt.fill", "Then run immediately",
                 "After the first payment, switch it on to fully automate."),
            ],
            primaryTitle: "Open Shortcuts",
            primaryURL: URL(string: "shortcuts://"),
            onContinue: { container.advanceOnboarding(to: .currency) },
            onBack: { container.advanceOnboarding(to: .backTapTeaser) },
            secondary: ("Use Back Tap instead", {
                container.advanceOnboarding(to: .backTapSetup)
            }),
            accessory: AnyView(QuickLogKeyCard(
                importShortcutURL: URL(string: Config.applePayShortcutImportURL),
                assignStep: "In your Wallet automation, choose 'Cashie Apple Pay Log' to run."
            )),
            primaryIcon: "arrow.up.forward.app"
        )
    }
}
