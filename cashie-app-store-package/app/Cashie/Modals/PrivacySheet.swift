import SwiftUI

/// Privacy & data controls. Hosts the privacy lock toggle and the
/// transaction CSV export. Kept intentionally short so beginners aren't
/// overwhelmed.
struct PrivacySheet: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var privacyLock: PrivacyLockService
    @Environment(\.dismiss) var dismiss

    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var showLockUnavailable = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                lockCard
                exportCard
                footer
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .alert("Face ID isn't set up", isPresented: $showLockUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Add a passcode or biometrics in iOS Settings, then come back to enable the lock.")
        }
        .sheet(isPresented: $showShare) {
            if let exportURL {
                ActivityView(activityItems: [exportURL])
                    .presentationDetents([.medium])
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Privacy & data")
                    .font(AppFont.title2)
                Text("Lock the app, take your data with you.")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(0.6).textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.Palette.bgCream))
            }
            .buttonStyle(.plainTappable)
        }
        .padding(.top, 14)
    }

    private var lockCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 14) {
                badge(systemImage: "lock.shield")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Privacy lock").font(AppFont.text(15, weight: .semibold))
                    Text("Require Face ID or your passcode to open Cashie.")
                        .font(AppFont.text(12))
                        .foregroundColor(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Toggle("", isOn: lockBinding)
                    .labelsHidden()
                    .tint(Theme.Palette.gold)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { container.settings.privacyLockEnabled },
            set: { newValue in
                guard newValue else {
                    container.settings.privacyLockEnabled = false
                    container.user.hasFaceID = false
                    return
                }
                guard privacyLock.verifyEligibility() else {
                    showLockUnavailable = true
                    return
                }
                // Prompt Face ID / passcode to confirm before turning the lock
                // on; only enable once the user actually authenticates.
                privacyLock.authenticateToEnable { ok in
                    guard ok else { return }
                    container.settings.privacyLockEnabled = true
                    container.user.hasFaceID = true
                }
            }
        )
    }

    private var exportCard: some View {
        Button(action: prepareExport) {
            HStack(spacing: 14) {
                badge(systemImage: "square.and.arrow.up")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export transactions")
                        .font(AppFont.text(15, weight: .semibold))
                        .foregroundColor(Theme.Palette.ink)
                    Text("Download a CSV of every logged transaction.")
                        .font(AppFont.text(12))
                        .foregroundColor(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Palette.inkMute)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plainTappable)
    }

    private var footer: some View {
        Text("We don't ship your data anywhere. Locks live on this phone.")
            .font(AppFont.text(11))
            .foregroundColor(Theme.Palette.inkMute)
            .multilineTextAlignment(.leading)
    }

    private func badge(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Theme.Palette.gold)
            .frame(width: 38, height: 38)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.goldPastel))
    }

    private func prepareExport() {
        guard let url = CSVExport.writeCSVFile(container.transactions) else { return }
        exportURL = url
        showShare = true
    }
}

/// Thin wrapper so we can present `UIActivityViewController` from SwiftUI.
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
