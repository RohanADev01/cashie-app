import SwiftUI

/// The Quick Log "how-to", rendered as a single vertical documentation page:
/// each step is one clear action with one short screenshot beneath it, in the
/// real end-to-end order (copy key → add shortcut → open Settings → map it).
/// No carousel, no swiping, no stacked cards, so a non-technical user can just
/// read top to bottom. Used by the onboarding setup screens and the You-tab
/// Quick Log setup sheet.
///
/// The guide owns the API-key load (Pro-verified mint via `AppContainer.quickLogKey`).
/// Copying the key calls `onCopied`, which the host screen turns into a top toast.
struct QuickLogVerticalGuide: View {
    enum Trigger { case backTap, actionButton }

    let trigger: Trigger
    /// Fired when the user copies the key, so the host can flash a top toast.
    var onCopied: () -> Void = {}

    @EnvironmentObject var container: AppContainer

    private enum KeyState: Equatable { case loading, ready(String), notPro, unavailable }
    @State private var keyState: KeyState = .loading

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                GuideStepRow(number: i + 1, title: step.title, subtitle: step.subtitle) {
                    step.content
                }
            }
            Text("Your key is private, do not share this with anyone.")
                .font(AppFont.text(11))
                .foregroundColor(Theme.Palette.inkMute)
                .padding(.top, 2)
        }
        .task { await load() }
    }

    // MARK: - Steps

    private struct GuideStep {
        let title: String
        var subtitle: String? = nil
        let content: AnyView
    }

    /// The ordered steps. Rebuilt on each pass so step 1 reflects the live key
    /// load state; steps 2+ never depend on the key, so they always render.
    private var steps: [GuideStep] {
        var s: [GuideStep] = [
            GuideStep(title: "Copy your API key", content: AnyView(keyContent)),
            GuideStep(
                title: "Add the shortcut",
                subtitle: "Tap below, then tap Add Shortcut, then paste your key when it asks",
                content: AnyView(
                    VStack(alignment: .leading, spacing: 10) {
                        chip(title: "Get the shortcut", icon: "square.and.arrow.down") {
                            open(URL(string: Config.quickLogShortcutImportURL))
                        }
                        GuideShot(imageName: "QLShot_AddShortcut")
                    }
                )
            ),
            GuideStep(
                title: "Open Settings",
                content: AnyView(
                    chip(title: "Open Settings", icon: "gearshape.fill") { open(settingsURL) }
                )
            ),
        ]
        for m in mappingSteps {
            s.append(GuideStep(title: m.title, content: AnyView(GuideShot(imageName: m.asset))))
        }
        return s
    }

    /// The in-Settings mapping, one action per step, each with its own screenshot.
    /// Back Tap walks through the iOS Settings path; Action Button is a single
    /// screenshot of its settings page set to the Cashie shortcut.
    private var mappingSteps: [(title: String, asset: String)] {
        switch trigger {
        case .backTap:
            return [
                ("Tap Accessibility", "QLShot_Accessibility"),
                ("Tap Touch", "QLShot_Touch"),
                ("Tap Back Tap", "QLShot_BackTap"),
                ("Choose Triple Tap", "QLShot_TripleTap"),
                ("Pick Cashie Quick Log", "QLShot_ChooseShortcut"),
            ]
        case .actionButton:
            return [
                ("Set the Action Button to Cashie Quick Log", "ActionButtonGuide"),
            ]
        }
    }

    // MARK: - Step 1 content (key states)

    @ViewBuilder private var keyContent: some View {
        switch keyState {
        case .loading:
            statusRow(spinner: true, "Getting your key ready")
        case .ready(let k):
            CopyKeyRow(key: k, onCopied: onCopied)
        case .notPro:
            statusRow(spinner: false, "Quick Log is a Cashie Pro feature")
        case .unavailable:
            VStack(alignment: .leading, spacing: 10) {
                statusRow(spinner: false, "Couldn't load your key. Check your connection.")
                chip(title: "Try again", icon: "arrow.clockwise") { Task { await load() } }
            }
        }
    }

    // MARK: - Bits

    private func chip(title: String, icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold))
                Text(title).font(AppFont.text(13, weight: .semibold))
            }
            .foregroundColor(Theme.Palette.gold)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(Theme.Palette.goldPastel))
        }
        .buttonStyle(.plainTappable)
    }

    private func statusRow(spinner: Bool, _ text: String) -> some View {
        HStack(spacing: 10) {
            if spinner { ProgressView().controlSize(.small) }
            Text(text)
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private var settingsURL: URL? {
        switch trigger {
        case .backTap: return URL(string: "App-prefs:ACCESSIBILITY")
        case .actionButton: return URL(string: "App-prefs:root=ACCESSIBILITY")
        }
    }

    private func open(_ url: URL?) {
        if let url { UIApplication.shared.open(url) }
    }

    private func load() async {
        keyState = .loading
        switch await container.quickLogKey() {
        case .ready(let k): keyState = .ready(k)
        case .notPro: keyState = .notPro
        case .unavailable: keyState = .unavailable
        }
    }
}

// MARK: - Step row

/// One step: a numbered heading (+ optional subtitle), then its content
/// (a key row, a screenshot, a chip) directly beneath. Stacked with no enclosing
/// card so the whole guide reads as one document.
struct GuideStepRow<Content: View>: View {
    let number: Int
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(number)")
                    .font(AppFont.text(13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Theme.Palette.ink))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppFont.title3)
                        .foregroundColor(Theme.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppFont.text(13))
                            .foregroundColor(Theme.Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            content()
        }
    }
}

// MARK: - Screenshot frame

/// A single step screenshot, framed consistently: full content width, rounded
/// corners, hairline border and a soft shadow so it reads as a phone capture on
/// the light setup background. Height follows the image's aspect.
struct GuideShot: View {
    let imageName: String

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.Palette.line, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Copy row

/// The API key (masked) with an inline circular copy button. No full-width
/// button: the user taps the circle, the key is copied, and the host flashes a
/// top "Copied!" toast via `onCopied`.
private struct CopyKeyRow: View {
    let key: String
    let onCopied: () -> Void

    @State private var copied = false

    var body: some View {
        HStack(spacing: 10) {
            Text(QuickLogKey.masked(key))
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(Theme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                UIPasteboard.general.string = key
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(Theme.Motion.quick) { copied = true }
                onCopied()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.Palette.gold))
            }
            .buttonStyle(.plainTappable)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }
}

// MARK: - Top toast

/// A top-pinned "Copied!" capsule, matching the app's existing toast styling
/// (see `StreakCalendarSheet`) but anchored to the top of the screen. Drive
/// `visible` from the host; it animates itself.
struct TopCopyToast: View {
    let visible: Bool
    var text: String = "Copied!"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
            Text(text)
                .font(AppFont.text(13, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Capsule().fill(Theme.Palette.ink))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .padding(.top, 10)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : -18)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: visible)
        .allowsHitTesting(false)
    }
}
