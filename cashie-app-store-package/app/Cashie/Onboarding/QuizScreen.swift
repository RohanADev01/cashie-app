import SwiftUI

struct QuizScreen: View {
    let questionIndex: Int     // 0...4
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var state: OnboardingState

    private var question: QuizQuestion { QuizBank.questions[questionIndex] }

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                header

                Text(question.kicker)
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .padding(.top, 16)

                EmphasizedHeadline(
                    raw: question.prompt,
                    font: AppFont.display(32, weight: .bold)
                )
                .fixedSize(horizontal: false, vertical: true)

                Text(question.helper)
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(question.options) { option in
                            QuizOptionButton(
                                option: option,
                                isSelected: state.quizAnswers[question.id] == option.id
                            ) {
                                select(option)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }

                Spacer(minLength: 0)

                if isLastQuestion {
                    PrimaryButton(title: "See my results") {
                        advance()
                    }
                    .opacity(state.quizAnswers[question.id] == nil ? 0.55 : 1)
                    .disabled(state.quizAnswers[question.id] == nil)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 62)
            .padding(.bottom, 28)
        }
    }

    private var isLastQuestion: Bool { questionIndex == 4 }

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: goBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.Palette.bgCream))
                    .overlay(Circle().stroke(Theme.Palette.line, lineWidth: 1))
            }
            .buttonStyle(.plainTappable)

            Text("0\(question.id) / 05")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.line)
                    Capsule()
                        .fill(Theme.Palette.ink)
                        .frame(width: proxy.size.width * progress)
                        .animation(Theme.Motion.smooth, value: progress)
                }
            }
            .frame(height: 3)
        }
        .padding(.top, 8)
    }

    private var progress: CGFloat { CGFloat(question.id) / 5.0 }

    private func select(_ option: QuizOption) {
        withAnimation(Theme.Motion.snap) {
            state.setQuizAnswer(question: question.id, optionID: option.id)
        }
        // Auto-advance for questions 1-4. Last question still needs the
        // "See my results" CTA so the user has a deliberate moment. The delay is
        // kept short so the quiz feels fast: just long enough to flash the
        // selected state before the next question slides in.
        guard !isLastQuestion else { return }
        let optID = option.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            // Guard against double-taps that change the selection mid-delay.
            guard state.quizAnswers[question.id] == optID else { return }
            advance()
        }
    }

    private func advance() {
        if isLastQuestion {
            state.computeArchetype()
            // Persist the marketing snapshot (answers + archetype + traits +
            // chips) to the synced profile once, here at quiz completion.
            container.recordQuizMarketingData(quizAnswers: state.quizAnswers,
                                              relatabilityChips: state.relatabilityChips,
                                              archetype: state.selectedArchetype,
                                              traits: state.traits)
            container.advanceOnboarding(to: .loading)
        } else {
            container.advanceOnboarding(to: .quiz(questionIndex + 2))
        }
    }

    private func goBack() {
        if questionIndex == 0 {
            container.advanceOnboarding(to: .intro)
        } else {
            container.advanceOnboarding(to: .quiz(questionIndex))
        }
    }
}

private struct QuizOptionButton: View {
    let option: QuizOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(option.main)
                    .font(AppFont.text(16, weight: .medium))
                    .foregroundColor(Theme.Palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.Palette.gold)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Theme.Palette.goldLight : Theme.Palette.bgCream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Theme.Palette.gold : Theme.Palette.line,
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plainTappable)
    }
}
