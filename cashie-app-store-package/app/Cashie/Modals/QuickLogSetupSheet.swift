import SwiftUI

/// Sheet-presented Quick Log setup. Walks the user from the pitch into picking a
/// trigger (Back Tap or Action Button) and mapping Cashie's shortcut to it. The
/// setup step is a single vertical how-to (`QuickLogVerticalGuide`). Opened from
/// the You tab or onboarding.
struct QuickLogSetupSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss
    @State private var step: Step = .teaser
    @State private var trigger: Trigger = .backTap

    @State private var showCopyToast = false
    @State private var copyToken = 0

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
        .overlay(alignment: .top) { TopCopyToast(visible: showCopyToast) }
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

    private func flashCopied() {
        copyToken += 1
        let token = copyToken
        showCopyToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            guard token == copyToken else { return }
            showCopyToast = false
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

    /// Tappable "method" card on the teaser. Picking one jumps to the setup
    /// step, preselected to that trigger.
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

    // MARK: - Step 2, the vertical guide

    /// The whole how-to for the chosen trigger on one page (copy key → add
    /// shortcut → open Settings → map it), with the actions pinned in a footer.
    private var setupView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Set it up")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Palette.inkSoft)

                    EmphasizedHeadline(raw: trigger.headline, font: AppFont.display(30, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)

                    QuickLogVerticalGuide(
                        trigger: trigger == .actionButton ? .actionButton : .backTap,
                        onCopied: { flashCopied() }
                    )
                    .padding(.top, 2)
                }
                .padding(.top, 2)
                .padding(.bottom, 16)
            }

            VStack(spacing: 10) {
                PrimaryButton(title: "I've set it up", trailingArrow: false, background: Theme.Palette.gold) {
                    step = .done
                }
                switchLink
            }
            .padding(.top, 10)
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

        /// Apple Pay is temporarily hidden from the picker. The case is kept so
        /// re-enabling it is just adding `.applePay` back to this list.
        static var allCases: [Trigger] { [.backTap, .actionButton] }

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
    }
}
