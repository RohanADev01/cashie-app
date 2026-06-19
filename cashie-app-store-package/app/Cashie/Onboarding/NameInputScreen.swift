import SwiftUI

/// Optional name capture during onboarding so we can greet the user by name.
/// Skippable; greetings fall back to a non-personalised line when no name is
/// set (see `CashieUser.hasName`).
struct NameInputScreen: View {
    @EnvironmentObject var container: AppContainer
    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            GoldBlob(alignment: .topTrailing, size: 360, intensity: 0.10)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("Nice to meet you")
                    .font(AppFont.text(11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .padding(.top, 14)

                EmphasizedHeadline(
                    raw: "What should we <em>call you?</em>",
                    font: AppFont.display(36, weight: .bold)
                )

                Text("First name's plenty, no pressure.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)
                    .padding(.top, 4)

                TextField("Your first name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($nameFocused)
                    .font(AppFont.text(20, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                trimmed.isEmpty ? Theme.Palette.line : Theme.Palette.gold,
                                lineWidth: 1
                            )
                    )
                    .submitLabel(.done)
                    .onSubmit(commit)
                    .padding(.top, 14)

                Spacer()

                PrimaryButton(title: "That's me") { commit() }
                    .opacity(trimmed.isEmpty ? 0.55 : 1)
                    .disabled(trimmed.isEmpty)
            }
            .padding(.horizontal, 28)
            .padding(.top, 60)
            .padding(.bottom, 28)
        }
        .onAppear {
            // Pre-populate if Apple already gave us a name; otherwise blank
            // (no default fallback - empty input forces the user to type one).
            if container.user.hasName {
                name = container.user.firstName
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                nameFocused = true
            }
        }
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        // Cap the stored name so a pasted wall of text can't break the
        // greeting layout on Today / You. A first name is never this long.
        container.user.firstName = String(trimmed.prefix(40))
        // Effort screen ("And now, the easy part") is hidden for now; jump
        // straight from name capture to the permissions step.
        container.advanceOnboarding(to: .permissions)
    }
}
