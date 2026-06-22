import SwiftUI

/// Shared screen body for the Quick Log setup steps. Back Tap and Action Button
/// pass in the new vertical guide (`quickLogGuide`); Apple Pay still uses the
/// older `steps` + `accessory` layout. The header + content scroll together; the
/// action buttons stay pinned in a bottom footer so Continue is always reachable.
struct GuidedSetupScreen: View {
    let pageLabel: String
    let kicker: String
    let title: String
    let onContinue: () -> Void
    let onBack: () -> Void
    let secondary: (label: String, action: () -> Void)?

    /// The vertical Quick Log guide (Back Tap / Action Button). When set, its
    /// copy action flashes the top "Copied!" toast owned by this screen.
    var quickLogGuide: ((@escaping () -> Void) -> AnyView)? = nil

    /// Apple Pay path only: the numbered automation steps, the key card, and the
    /// open-app button.
    var steps: [(icon: String, title: String, body: String)] = []
    var accessory: AnyView? = nil
    var primaryTitle: String = ""
    var primaryURL: URL? = nil
    var primaryIcon: String = "gearshape.fill"

    @State private var showCopyToast = false
    @State private var copyToken = 0

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

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

                        if let quickLogGuide {
                            quickLogGuide({ flashCopied() })
                                .padding(.top, 2)
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
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }

                footer
            }
        }
        .overlay(alignment: .top) { TopCopyToast(visible: showCopyToast) }
    }

    /// Pinned action buttons. Open-app button (Apple Pay only), then Continue,
    /// then an optional switch link.
    private var footer: some View {
        VStack(spacing: 10) {
            if let url = primaryURL {
                PrimaryButton(title: primaryTitle, systemImage: primaryIcon, trailingArrow: false) {
                    UIApplication.shared.open(url)
                }
            }

            PrimaryButton(title: "I've set it up · Continue") {
                onContinue()
            }

            if let s = secondary {
                Button(s.label, action: s.action)
                    .font(AppFont.text(12, weight: .medium))
                    .foregroundColor(Theme.Palette.gold)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            Theme.Palette.bg
                .overlay(Rectangle().fill(Theme.Palette.line).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func flashCopied() {
        copyToken += 1
        let token = copyToken
        showCopyToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            guard token == copyToken else { return }
            showCopyToast = false
        }
    }
}

struct BackTapSetupScreen: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        GuidedSetupScreen(
            pageLabel: "Quick Log · Back Tap",
            kicker: "iPhone 8–14",
            title: "Set up your <em>Back Tap</em>",
            onContinue: { container.advanceOnboarding(to: .currency) },
            onBack: { container.advanceOnboarding(to: .backTapTeaser) },
            secondary: ("My phone has the Action Button, switch", {
                container.advanceOnboarding(to: .actionButtonSetup)
            }),
            quickLogGuide: { onCopied in
                AnyView(QuickLogVerticalGuide(trigger: .backTap, onCopied: onCopied))
            }
        )
    }
}

struct ActionButtonSetupScreen: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        GuidedSetupScreen(
            pageLabel: "Quick Log · Action Button",
            kicker: "iPhone 15 Pro+",
            title: "Set up your <em>Action Button</em>",
            onContinue: { container.advanceOnboarding(to: .currency) },
            onBack: { container.advanceOnboarding(to: .backTapTeaser) },
            secondary: ("Use Back Tap instead", {
                container.advanceOnboarding(to: .backTapSetup)
            }),
            quickLogGuide: { onCopied in
                AnyView(QuickLogVerticalGuide(trigger: .actionButton, onCopied: onCopied))
            }
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
            onContinue: { container.advanceOnboarding(to: .currency) },
            onBack: { container.advanceOnboarding(to: .backTapTeaser) },
            secondary: ("Use Back Tap instead", {
                container.advanceOnboarding(to: .backTapSetup)
            }),
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
            accessory: AnyView(QuickLogKeyCard(
                importShortcutURL: URL(string: Config.applePayShortcutImportURL),
                assignStep: "In your Wallet automation, choose 'Cashie Apple Pay Log' to run."
            )),
            primaryTitle: "Open Shortcuts",
            primaryURL: URL(string: "shortcuts://"),
            primaryIcon: "arrow.up.forward.app"
        )
    }
}
