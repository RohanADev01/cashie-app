import SwiftUI

/// Sheet-presented Quick Log setup. Walks the user from the pitch into picking a
/// trigger (Back Tap, Action Button, Siri, or an NFC tag) and assigning Cashie's
/// shortcut to it. The shortcuts themselves are published automatically by
/// `CashieShortcuts` (App Intents), so there's nothing to import; this screen is
/// pure guidance. Opened from the You tab or onboarding.
struct QuickLogSetupSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss
    @State private var step: Step = .teaser
    @State private var trigger: Trigger = .backTap

    enum Step { case teaser, setup, done }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                Group {
                    switch step {
                    case .teaser: teaser
                    case .setup: setupView
                    case .done: doneView
                    }
                }
                .transition(.opacity)
                .animation(Theme.Motion.smooth, value: step)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
        }
    }

    private var header: some View {
        HStack {
            Button(action: back) {
                Image(systemName: (step == .teaser || step == .done) ? "xmark" : "arrow.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.Palette.bgCream))
            }
            .buttonStyle(.plainTappable)
            Spacer()
            Text("Quick Log setup")
                .font(AppFont.text(13, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func back() {
        switch step {
        case .teaser: dismiss()
        case .setup: step = .teaser
        case .done: dismiss()
        }
    }

    // MARK: - Step 1, Teaser

    private var teaser: some View {
        VStack(spacing: 12) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("The 2-second log")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.inkSoft)

                    EmphasizedHeadline(
                        raw: "Two ways to <em>log a spend.</em>",
                        font: AppFont.display(34, weight: .bold)
                    )

                    Text("Pick one. Each logs in seconds with no typing in the app. You only set it up once.")
                        .font(AppFont.callout)
                        .foregroundColor(Theme.Palette.inkSoft)

                    VStack(spacing: 10) {
                        ForEach(Trigger.allCases) { t in
                            methodCard(t)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 6)
                .padding(.bottom, 8)
            }

            PrimaryButton(title: "Set it up", trailingArrow: false, background: Theme.Palette.gold) {
                step = .setup
            }
            GhostButton(title: "Maybe later") { dismiss() }
        }
    }

    /// Tappable "method" card on the teaser. Picking one jumps to the key step,
    /// then lands on that trigger's instructions preselected.
    private func methodCard(_ t: Trigger) -> some View {
        Button(action: { trigger = t; step = .setup }) {
            HStack(spacing: 14) {
                Image(systemName: t.cardIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.Palette.gold)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.goldLight))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.chip)
                        .font(AppFont.text(15, weight: .semibold))
                        .foregroundColor(Theme.Palette.ink)
                    Text(t.cardBlurb)
                        .font(AppFont.text(12))
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkMute)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plainTappable)
    }

    // MARK: - Step 2, API key + import

    // MARK: - Step 2, single combined setup page (matches onboarding)

    /// Everything for the chosen trigger on one page: the numbered 1–4 steps,
    /// then the visual guide (swipe for Back Tap, screenshot for Action Button),
    /// then the API key + import controls. A switch link swaps triggers inline,
    /// so there's no separate redundant "pick a trigger" step.
    private var setupView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Set it up")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)

                EmphasizedHeadline(raw: trigger.headline, font: AppFont.display(30, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                // a) the numbered 1–4 steps
                QuickLogStepsCard(assignStep: trigger.assignStep)

                // b) the visual guide
                if trigger == .backTap {
                    Text("Watch how")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SetupWalkthrough.backTap
                } else if trigger == .actionButton {
                    SettingsScreenshotCard(
                        imageName: "ActionButtonGuide",
                        caption: "Set the Action Button to 'Cashie Quick Log'.",
                        maxHeight: 300
                    )
                }

                // c) the API key + copy + import controls (steps shown above)
                QuickLogKeyCard(importShortcutURL: trigger.importURL,
                                assignStep: trigger.assignStep,
                                showSteps: false)

                triggerActions
                switchLink
            }
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
    }

    /// Swaps to the other tap trigger inline (Back Tap <-> Action Button) so the
    /// user never has to back out to re-pick.
    private var switchLink: some View {
        let other: Trigger = (trigger == .backTap) ? .actionButton : .backTap
        let label = (trigger == .backTap)
            ? "My phone has the Action Button, switch"
            : "Use Back Tap instead"
        return Button(label) { withAnimation { trigger = other } }
            .font(AppFont.text(12, weight: .medium))
            .foregroundColor(Theme.Palette.gold)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }

    @ViewBuilder
    private var triggerActions: some View {
        if let url = trigger.actionURL {
            PrimaryButton(title: trigger.actionLabel,
                          systemImage: trigger.actionIcon,
                          trailingArrow: false,
                          background: Theme.Palette.gold) {
                UIApplication.shared.open(url)
            }
        }
        GhostButton(title: "I've set it up") { step = .done }
    }

    // MARK: - Step 3, Done

    private var doneView: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle().fill(Theme.Palette.goldPastel)
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(Theme.Palette.gold)
            }
            EmphasizedHeadline(
                raw: "<em>You're set.</em>",
                font: AppFont.display(40, weight: .bold)
            )
            Text("Fire your trigger and log a spend in seconds. It lands in Cashie on your next open.")
                .font(AppFont.callout)
                .foregroundColor(Theme.Palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Spacer()
            PrimaryButton(title: "Done", trailingArrow: false, background: Theme.Palette.gold) {
                container.user.quickLogSetup = true
                dismiss()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Trigger content

private extension QuickLogSetupSheet {
    enum Trigger: String, CaseIterable, Identifiable {
        case backTap, actionButton, applePay
        var id: String { rawValue }

        /// Apple Pay is temporarily hidden from the picker. The case (and all its
        /// copy/steps below) is kept intact, so re-enabling it is just adding
        /// `.applePay` back to this list.
        static var allCases: [Trigger] { [.backTap, .actionButton] }

        /// The name of the shortcut the user imports for this trigger. The
        /// tap-based triggers share one shortcut; Apple Pay uses its own.
        var shortcutName: String {
            self == .applePay ? "Cashie Apple Pay Log" : "Cashie Quick Log"
        }

        /// The iCloud import link for this trigger's shortcut. Two workflows,
        /// two links (see `Config`).
        var importURL: URL? {
            URL(string: self == .applePay
                ? Config.applePayShortcutImportURL
                : Config.quickLogShortcutImportURL)
        }

        /// The key card's final "assign" how-to line for this trigger.
        var assignStep: String {
            switch self {
            case .backTap: return "Assign the shortcut to Back Tap (triple tap)."
            case .actionButton: return "Assign the shortcut to the Action Button."
            case .applePay: return "In your Wallet automation, choose 'Cashie Apple Pay Log' to run."
            }
        }

        var chip: String {
            switch self {
            case .backTap: return "Back Tap"
            case .actionButton: return "Action Button"
            case .applePay: return "Apple Pay"
            }
        }

        /// Icon + one-liner for the "pick a method" cards on the teaser.
        var cardIcon: String {
            switch self {
            case .backTap: return "hand.tap.fill"
            case .actionButton: return "bolt.fill"
            case .applePay: return "creditcard.fill"
            }
        }

        var cardBlurb: String {
            switch self {
            case .backTap: return "Triple-tap the back of your phone."
            case .actionButton: return "One press on iPhone 15 Pro and newer."
            case .applePay: return "Logs right after you pay with Apple Pay."
            }
        }

        var headline: String {
            switch self {
            case .backTap: return "Map your <em>triple tap.</em>"
            case .actionButton: return "Map your <em>Action Button.</em>"
            case .applePay: return "Log <em>after Apple Pay.</em>"
            }
        }

        var note: String? {
            switch self {
            case .applePay:
                return "Apple Pay can't share the amount, so the shortcut asks you to confirm it. The first run needs confirmation; after that you can let it run on its own."
            default:
                return nil
            }
        }

        /// (SF Symbol, title, body) per step. The icon is the small visual cue.
        var steps: [(icon: String, title: String, body: String)] {
            switch self {
            case .backTap:
                return [
                    ("gearshape.fill", "Open Settings", "Go to Accessibility, then Touch, then Back Tap."),
                    ("hand.tap.fill", "Tap Triple Tap", "Pick the triple-tap option."),
                    ("checkmark.circle.fill", "Choose \(shortcutName)", "Select the shortcut you imported.")
                ]
            case .actionButton:
                return [
                    ("gearshape.fill", "Open Settings", "Find Action Button."),
                    ("hand.draw.fill", "Swipe to Shortcut", "Pick the Shortcut option."),
                    ("checkmark.circle.fill", "Choose \(shortcutName)", "Select the shortcut you imported.")
                ]
            case .applePay:
                return [
                    ("square.grid.2x2.fill", "Open Shortcuts", "Go to the Automation tab."),
                    ("plus.circle.fill", "Create Personal Automation", "Tap +, then Create Personal Automation."),
                    ("creditcard.fill", "Select Wallet", "Pick your card, then choose \(shortcutName) to run."),
                    ("checkmark.seal.fill", "Run After Confirmation", "Leave this on for your first payment."),
                    ("bolt.fill", "Then run immediately", "After the first payment, switch it on to fully automate.")
                ]
            }
        }

        var actionLabel: String {
            switch self {
            case .backTap, .actionButton: return "Open Settings"
            case .applePay: return "Open Shortcuts"
            }
        }

        var actionURL: URL? {
            switch self {
            case .backTap: return URL(string: "App-prefs:ACCESSIBILITY")
            case .actionButton: return URL(string: "App-prefs:root=ACCESSIBILITY")
            case .applePay: return URL(string: "shortcuts://")
            }
        }

        var actionIcon: String {
            switch self {
            case .applePay: return "arrow.up.forward.app"
            default: return "gearshape.fill"
            }
        }
    }
}
