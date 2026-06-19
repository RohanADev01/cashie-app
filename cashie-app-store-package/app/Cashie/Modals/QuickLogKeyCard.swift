import SwiftUI

/// Reusable card: shows the user's Quick Log API key (masked, with reveal +
/// copy), the "Import Shortcut" button, and the paste-the-key steps. Used in the
/// You-tab Quick Log setup sheet and in onboarding.
///
/// The key is minted server-side (Pro-verified) via `AppContainer.quickLogKey`
/// and cached on-device, so the value the user copies is registered and accepted
/// by the Quick Log endpoint.
///
/// `importShortcutURL` is the iCloud Shortcut link the "Import Shortcut" button
/// opens. It defaults to the tap-to-log shortcut (`Config.quickLogShortcutImportURL`);
/// the Apple Pay flow overrides it with `Config.applePayShortcutImportURL`.
/// `assignStep` is the final how-to line, which differs by workflow.
struct QuickLogKeyCard: View {
    var importShortcutURL: URL? = URL(string: Config.quickLogShortcutImportURL)
    var assignStep: String = "Assign the shortcut to Back Tap or the Action Button."

    @EnvironmentObject var container: AppContainer

    private enum LoadState: Equatable { case loading, ready, notPro, unavailable }

    @State private var key: String = ""
    @State private var loadState: LoadState = .loading
    @State private var revealed = false
    @State private var copied = false
    @State private var resetting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Quick Log API key")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)

            switch loadState {
            case .loading:
                statusRow(spinner: true, "Preparing your key…")
            case .notPro:
                statusRow(spinner: false, "Quick Log is a Cashie Pro feature.")
            case .unavailable:
                unavailableBlock
            case .ready:
                readyBlock
            }
        }
        .task { await load() }
    }

    // MARK: - States

    private var readyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(revealed ? key : QuickLogKey.masked(key))
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(Theme.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: { revealed.toggle() }) {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                .buttonStyle(.plainTappable)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.bgCream))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))

            PrimaryButton(title: copied ? "Copied" : "Copy API key",
                          systemImage: copied ? "checkmark" : "doc.on.doc",
                          trailingArrow: false,
                          background: Theme.Palette.gold) {
                UIPasteboard.general.string = key
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation { copied = false }
                }
            }

            PrimaryButton(title: "Import Shortcut",
                          systemImage: "square.and.arrow.down",
                          trailingArrow: false,
                          background: Theme.Palette.ink) {
                if let url = importShortcutURL {
                    UIApplication.shared.open(url)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                step("1", "Copy your API key.")
                step("2", "Tap Import Shortcut, then Add Shortcut in the Shortcuts app.")
                step("3", "Paste your key into the x-api-key prompt.")
                step("4", assignStep)
            }
            .padding(.top, 2)

            Text("Your key is private. It can only add a spend, never read or delete your data.")
                .font(AppFont.text(11))
                .foregroundColor(Theme.Palette.inkMute)

            Button(action: { Task { await resetKey() } }) {
                Text(resetting ? "Resetting…" : "Reset key")
                    .font(AppFont.text(11, weight: .semibold))
                    .underline()
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            .buttonStyle(.plainTappable)
            .disabled(resetting)
        }
    }

    private var unavailableBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusRow(spinner: false, "Couldn't load your key. Check your connection.")
            PrimaryButton(title: "Try again",
                          systemImage: "arrow.clockwise",
                          trailingArrow: false,
                          background: Theme.Palette.ink) {
                Task { await load() }
            }
        }
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

    // MARK: - Loading

    private func load() async {
        loadState = .loading
        apply(await container.quickLogKey())
    }

    private func resetKey() async {
        resetting = true
        apply(await container.quickLogKey(reset: true))
        resetting = false
    }

    private func apply(_ result: AppContainer.QuickLogKeyResult) {
        switch result {
        case .ready(let k):
            key = k
            loadState = .ready
        case .notPro:
            loadState = .notPro
        case .unavailable:
            loadState = .unavailable
        }
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(AppFont.text(11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.Palette.ink))
            Text(text)
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.ink)
            Spacer(minLength: 0)
        }
    }
}
