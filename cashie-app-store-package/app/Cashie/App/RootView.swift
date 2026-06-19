import SwiftUI
import UIKit
import Combine

struct RootView: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var privacyLock: PrivacyLockService

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            switch container.session {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .onboarding(let step):
                OnboardingHost(step: step)
                    .transition(.opacity)
            case .main:
                MainTabsView()
                    .transition(.opacity)
            }

            // Small global "Saving…/Saved" indicator for in-flight actions.
            // Sits above content but below the privacy veil.
            SyncStatusBar(indicator: container.syncIndicator)
                .zIndex(50)

            if privacyLock.isLocked {
                PrivacyLockVeil { privacyLock.requestUnlockIfNeeded() }
                    .transition(.opacity)
                    .zIndex(99)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Re-check the entitlement on every foreground so an expired
            // subscription bounces the user back to the paywall instead of
            // silently letting them keep using Pro features.
            Task { await container.refreshSubscription() }
            // Also re-pull any remote changes and flush queued writes.
            Task { await container.resync() }
            // Count the resume as a session open, then deliver any analytics
            // events buffered while offline / backgrounded.
            container.track("app_opened")
            Task { await container.flushAnalytics() }
            // Catch any badge/rank that became earned purely from time passing
            // while backgrounded (a new month for loyalty, a streak day rolling
            // over). Sync-driven changes re-check via reloadFromLocal.
            container.evaluateAchievements()
        }
    }
}

/// A small, unobtrusive pill that shows "Saving…" while a write is in flight and
/// flashes "Saved" when it settles, then fades out. It is driven purely by the
/// in-flight action count and has a watchdog auto-hide, so it can never get
/// stuck on screen even if an operation never reports completion.
private struct SyncStatusBar: View {
    @ObservedObject var indicator: SyncIndicator
    @State private var phase: Phase = .hidden
    @State private var hideWork: DispatchWorkItem?

    private enum Phase: Equatable { case hidden, saving, saved }

    var body: some View {
        VStack {
            pill.padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .animation(Theme.Motion.snap, value: phase)
        .allowsHitTesting(false)
        .onAppear { if indicator.isActive { showSaving() } }
        .onReceive(indicator.$activeCount) { count in
            if count > 0 { showSaving() }
            else if phase != .hidden { showSavedThenHide() }
        }
    }

    @ViewBuilder private var pill: some View {
        if phase != .hidden {
            HStack(spacing: 7) {
                if phase == .saving {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                    Text("Saving")
                        .font(AppFont.text(11, weight: .semibold))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Saved")
                        .font(AppFont.text(11, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(phase == .saved ? Theme.Palette.green : Theme.Palette.ink.opacity(0.92))
            )
            .shadow(color: Theme.Palette.cardShadow, radius: 8, y: 3)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func showSaving() {
        phase = .saving
        // Watchdog: never let the pill stick, even if a count never resolves.
        scheduleHide(after: 14, to: .hidden)
    }

    private func showSavedThenHide() {
        phase = .saved
        scheduleHide(after: 1.0, to: .hidden)
    }

    private func scheduleHide(after seconds: Double, to target: Phase) {
        hideWork?.cancel()
        let work = DispatchWorkItem { phase = target }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}
