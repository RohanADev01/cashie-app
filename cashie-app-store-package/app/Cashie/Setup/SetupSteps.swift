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
    /// Optional content shown directly under the headline, above the visual
    /// guide (e.g. the numbered 1–4 setup steps).
    var topContent: AnyView? = nil
    /// Optional looping walkthrough animation (or a screenshot guide) shown with
    /// the numbered steps.
    var walkthrough: AnyView? = nil
    /// Heading shown above `walkthrough`. "Watch how" for the animated mock; a
    /// static screenshot guide passes nil so no heading shows (matching the You
    /// tab modal, where the screenshot stands on its own).
    var walkthroughLabel: String? = "Watch how"
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

                        if let topContent { topContent }

                        if let walkthrough {
                            if let walkthroughLabel {
                                Text(walkthroughLabel)
                                    .font(AppFont.text(11, weight: .semibold))
                                    .tracking(2)
                                    .textCase(.uppercase)
                                    .foregroundColor(Theme.Palette.inkSoft)
                                    .padding(.top, 2)
                            }
                            walkthrough
                        }

                        if let accessory { accessory }

                        if !steps.isEmpty {
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
            // Order: 1–4 steps, then the swipeable walkthrough, then the API key
            // card. The redundant "Settings → Accessibility" cards are gone since
            // the walkthrough already shows that flow.
            steps: [],
            primaryTitle: "Open Settings",
            primaryURL: URL(string: "App-prefs:ACCESSIBILITY"),
            onContinue: { container.advanceOnboarding(to: .currency) },
            onBack: { container.advanceOnboarding(to: .backTapTeaser) },
            secondary: ("My phone has the Action Button, switch", {
                container.advanceOnboarding(to: .actionButtonSetup)
            }),
            accessory: AnyView(QuickLogKeyCard(assignStep: "Assign the shortcut to Back Tap (triple tap).",
                                               showSteps: false)),
            topContent: AnyView(QuickLogStepsCard(assignStep: "Assign the shortcut to Back Tap (triple tap).")),
            walkthrough: AnyView(SetupWalkthrough.backTap)
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
            // Order: 1–4 steps, then the screenshot guide, then the API key card.
            // No "Settings → Action Button" cards since the screenshot covers it.
            steps: [],
            primaryTitle: "Open Settings",
            primaryURL: URL(string: "App-prefs:root=ACCESSIBILITY"),
            onContinue: { container.advanceOnboarding(to: .currency) },
            onBack: { container.advanceOnboarding(to: .backTapTeaser) },
            secondary: ("Use Back Tap instead", {
                container.advanceOnboarding(to: .backTapSetup)
            }),
            accessory: AnyView(QuickLogKeyCard(assignStep: "Assign the shortcut to the Action Button.",
                                               showSteps: false)),
            topContent: AnyView(QuickLogStepsCard(assignStep: "Assign the shortcut to the Action Button.")),
            walkthrough: AnyView(SettingsScreenshotCard(
                imageName: "ActionButtonGuide",
                caption: "Set the Action Button to 'Cashie Quick Log'.",
                maxHeight: 300)),
            walkthroughLabel: nil
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

/// A bundled iOS screenshot shown as a visual guide in the Quick Log setup
/// screens (e.g. the Action Button settings page with Cashie Quick Log
/// assigned). Framed with rounded corners + a soft shadow so it reads as a
/// phone screen on the light setup background.
struct SettingsScreenshotCard: View {
    let imageName: String
    var caption: String? = nil
    var maxHeight: CGFloat = 320

    /// The screenshot's width/height, read from the bundled image so the frame
    /// hugs it tightly (no letterbox border around a tall, narrow capture).
    private var aspect: CGFloat {
        guard let ui = UIImage(named: imageName), ui.size.height > 0 else { return 0.52 }
        return ui.size.width / ui.size.height
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: maxHeight * aspect, height: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.Palette.line, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
            if let caption {
                Text(caption)
                    .font(AppFont.text(12, weight: .medium))
                    .foregroundColor(Theme.Palette.inkMute)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
