import SwiftUI

@main
struct CashieApp: App {
    @StateObject private var container: AppContainer
    @StateObject private var privacyLock: PrivacyLockService

    init() {
        #if DEBUG
        // -emptyStore seeds a clean, EMPTY account (no transactions/goals, just
        // the default category budgets) so the simulator can preview true
        // first-run empty states. Must run before AppContainer is built, since
        // the store service reads its seed in its initializer. Compiled out of
        // release builds.
        // -seedDemo also starts from a clean store so DemoSeed (applied after
        // bootstrap, below) populates a fresh account every launch rather than
        // stacking duplicates on top of the last run.
        if ProcessInfo.processInfo.arguments.contains("-emptyStore")
            || ProcessInfo.processInfo.arguments.contains("-seedDemo") {
            LocalStore.shared.wipe()
            LocalStore.shared.save([Transaction](), key: LocalStore.Key.transactions)
            LocalStore.shared.save([Goal](), key: LocalStore.Key.goals)
            LocalStore.shared.save([AppNotification](), key: LocalStore.Key.notifications)
            LocalStore.shared.save(CategoryBudget.seed, key: LocalStore.Key.budgets)
            LocalStore.shared.save(AppSettings(), key: LocalStore.Key.settings)
            UserDefaults.standard.set(true, forKey: LocalStore.Key.seeded)
        }
        #endif
        // Subscriptions run on native StoreKit 2 (no third-party SDK). The
        // simulator opens the real iOS purchase sheet via the Cashie.storekit
        // configuration on the scheme; device + App Store builds talk to the
        // real App Store.
        let subscriptions: SubscriptionService = StoreKitService()

        let c = AppContainer(supabase: MockSupabaseService(), subscriptions: subscriptions)
        let lock = PrivacyLockService()
        #if DEBUG
        // Dev/simulator affordances only. Compiled out of release builds, so the
        // shipping binary carries no state-reset or screen-jump launch arguments.
        let args = ProcessInfo.processInfo.arguments
        // -resetPaywall clears the sticky paywall flag so the simulator can flow through onboarding again.
        if args.contains("-resetPaywall") {
            UserDefaults.standard.removeObject(forKey: "hasReachedPaywall")
        }
        // -resetSubscription wipes the persisted subscription marker so relaunches re-show the paywall.
        if args.contains("-resetSubscription") {
            UserDefaults.standard.removeObject(forKey: "isSubscribed")
        }
        // -resetStore wipes all persisted user data (transactions, goals, budgets, settings)
        // so the simulator boots into a clean first-launch state.
        if args.contains("-resetStore") {
            LocalStore.shared.wipe()
            UserDefaults.standard.removeObject(forKey: LocalStore.Key.seeded)
        }
        // SplashView consults the subscription gateway on every launch and
        // routes the user to either main, paywall, or onboarding. The
        // -startAt override below still wins for dev builds.
        // Dev affordance, launch with `-startAt <screen>` to jump straight to a
        // specific screen during simulator testing. Has no effect in release.
        if let value = args
            .firstIndex(of: "-startAt").flatMap({ idx in args[safe: idx + 1] }) {
            c.session = SessionState.fromShortcut(value) ?? .splash
        }
        // -archetype <id> overrides the user's current archetype for previewing.
        if let raw = args
            .firstIndex(of: "-archetype").flatMap({ idx in args[safe: idx + 1] }),
           let id = ArchetypeID(rawValue: raw) {
            c.user.archetype = Archetype.by(id: id)
        }
        #endif
        _container = StateObject(wrappedValue: c)
        _privacyLock = StateObject(wrappedValue: lock)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(privacyLock)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    // cashie:// deep links from Shortcuts (Back Tap / Action
                    // Button / NFC) or anywhere else open Quick Log, prefilled.
                    if let prefill = DeepLink.parse(url) {
                        container.presentQuickLog(prefill)
                    }
                }
                .onReceive(QuickLogLaunch.shared.$pending) { prefill in
                    // OpenQuickLogIntent ran and asked us to show the sheet.
                    guard let prefill else { return }
                    container.presentQuickLog(prefill)
                    QuickLogLaunch.shared.pending = nil
                }
                .task {
                    await container.bootstrap()
                    #if DEBUG
                    // Populate the demo fixture once the (wiped) account has loaded.
                    if ProcessInfo.processInfo.arguments.contains("-seedDemo") {
                        DemoSeed.apply(to: container)
                    }
                    #endif
                    privacyLock.attach(to: container)
                    await ReminderScheduler.sync(with: container.settings)
                    await ReminderScheduler.scheduleRateReminderIfNeeded()
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-syncSelfTest") {
                        await container.runSyncSelfTest()
                    }
                    #endif
                }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension SessionState {
    static func fromShortcut(_ s: String) -> SessionState? {
        switch s {
        case "splash": return .splash
        case "welcome": return .onboarding(.welcome)
        case "relatability": return .onboarding(.relatability)
        case "intro": return .onboarding(.intro)
        case "quiz": return .onboarding(.quiz(1))
        case "loading": return .onboarding(.loading)
        case "reveal": return .onboarding(.reveal)
        case "traits": return .onboarding(.traits)
        case "pain": return .onboarding(.pain)
        case "quickLog": return .onboarding(.quickLogIntro)
        case "effort": return .onboarding(.effort)
        case "social": return .onboarding(.socialProof)
        case "reviews": return .onboarding(.reviews)
        case "contrast": return .onboarding(.contrast)
        case "paywall": return .onboarding(.paywall)
        case "welcomeIn": return .onboarding(.welcomeIn)
        case "nameInput": return .onboarding(.nameInput)
        case "permissions": return .onboarding(.permissions)
        case "backTapIntro": return .onboarding(.backTapIntro)
        case "backTap": return .onboarding(.backTapTeaser)
        case "backTapSetup": return .onboarding(.backTapSetup)
        case "actionButton": return .onboarding(.actionButtonSetup)
        case "applePay": return .onboarding(.applePaySetup)
        case "currency": return .onboarding(.currency)
        case "ready": return .onboarding(.ready)
        case "main": return .main
        default: return nil
        }
    }
}
