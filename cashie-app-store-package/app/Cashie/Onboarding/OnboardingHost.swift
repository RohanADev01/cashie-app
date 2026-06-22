import SwiftUI

/// Host that picks the right screen for the current onboarding step + holds
/// shared in-flight state (quiz answers, selected archetype, etc.).
struct OnboardingHost: View {
    let step: OnboardingStep
    @EnvironmentObject var container: AppContainer
    @StateObject private var state = OnboardingState()
    /// Hydrate the freshly-created state from persisted progress exactly once
    /// per launch (the host stays mounted across steps, so onAppear fires once).
    @State private var didHydrate = false

    var body: some View {
        ZStack {
            Theme.pageBackground.ignoresSafeArea()
            content
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
                .id(step)
        }
        .environmentObject(state)
        .animation(Theme.Motion.smooth, value: step)
        .onAppear {
            // PostHog: log a screen view for the first onboarding screen shown.
            container.track("onboarding_screen_view", ["screen": step.persistedID])
            guard !didHydrate else { return }
            didHydrate = true
            state.hydrate(from: container.onboardingProgress)
        }
        // PostHog: log a screen view on every subsequent onboarding screen, so
        // the funnel covers every step (incl. resume) regardless of entry path.
        .onChange(of: step) { newStep in
            container.track("onboarding_screen_view", ["screen": newStep.persistedID])
        }
        // Persist in-flight answers locally so a relaunch resumes with them.
        .onChange(of: state.quizAnswers) { _ in
            container.recordOnboardingAnswers(quizAnswers: state.quizAnswers,
                                              relatabilityChips: state.relatabilityChips)
        }
        .onChange(of: state.relatabilityChips) { _ in
            container.recordOnboardingAnswers(quizAnswers: state.quizAnswers,
                                              relatabilityChips: state.relatabilityChips)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: WelcomeScreen()
        // The old chat screen (RelatabilityScreen) has been retired from the
        // flow but kept in the repo; this step now shows the tap-through
        // feature tour instead.
        case .relatability: FeatureTourScreen()
        case .intro: IntroScreen()
        case .quiz(let n): QuizScreen(questionIndex: n - 1)
        case .loading: LoadingScreen()
        case .reveal: RevealScreen()
        case .traits: TraitsScreen()
        case .pain: PainScreen()
        case .quickLogIntro: QuickLogIntroScreen()
        case .effort: EffortScreen()
        case .socialProof: SocialProofScreen()
        case .reviews: ReviewsScreen()
        case .contrast: ContrastScreen()
        case .paywall: PaywallScreen()
        case .welcomeIn: WelcomeInScreen()
        case .nameInput: NameInputScreen()
        case .permissions: PermissionsScreen()
        case .backTapIntro: BackTapTeaserScreen()  // legacy step alias; intro screen retired
        case .backTapTeaser: BackTapTeaserScreen()
        case .backTapSetup: BackTapSetupScreen()
        case .actionButtonSetup: ActionButtonSetupScreen()
        case .applePaySetup: ApplePaySetupScreen()
        case .currency: CurrencyScreen()
        case .ready: ReadyScreen()
        }
    }
}

@MainActor
final class OnboardingState: ObservableObject {
    @Published var relatabilityChips: Set<String> = []
    /// Selected option IDs in order, indexed by question (1...5).
    @Published var quizAnswers: [Int: String] = [:]
    @Published var selectedArchetype: Archetype = OnboardingState.initialArchetype
    @Published var traits: [Trait] = OnboardingState.defaultTraits

    private static var initialArchetype: Archetype {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-archetype"), i + 1 < args.count,
           let id = ArchetypeID(rawValue: args[i + 1]) {
            return Archetype.by(id: id)
        }
        return .default
    }

    func setQuizAnswer(question: Int, optionID: String) {
        quizAnswers[question] = optionID
    }

    /// Restores in-flight onboarding selections after a relaunch. If the quiz was
    /// already fully answered, recompute the archetype/traits (the scorer is pure)
    /// so the reveal/traits screens render correctly on resume.
    func hydrate(from progress: OnboardingProgress) {
        relatabilityChips = Set(progress.relatabilityChips)
        quizAnswers = progress.quizAnswers.reduce(into: [:]) { dict, kv in
            if let q = Int(kv.key) { dict[q] = kv.value }
        }
        if (1...5).allSatisfy({ quizAnswers[$0] != nil }) {
            computeArchetype()
        }
    }

    func computeArchetype() {
        let ordered = (1...5).compactMap { quizAnswers[$0] }
        let (arch, traits) = QuizScorer.score(answers: ordered)
        self.selectedArchetype = arch
        self.traits = traits
    }

    /// Reasonable defaults so reveal/traits/pain screens still render if a
    /// user deep-links into them without completing the quiz.
    private static let defaultTraits: [Trait] = [
        Trait(trait: .impulse, score: 78,
              blurb: "Decisions land in under 8 seconds. We'll add a pause."),
        Trait(trait: .planning, score: 42,
              blurb: "Plans exist, mostly. Cashie fills the gaps."),
        Trait(trait: .awareness, score: 56,
              blurb: "You glance, but the whole picture is missing."),
        Trait(trait: .security, score: 48,
              blurb: "A buffer would feel good. We'll suggest one."),
        Trait(trait: .enjoyment, score: 71,
              blurb: "Money is for living. We'll show you the safe yes."),
    ]
}
