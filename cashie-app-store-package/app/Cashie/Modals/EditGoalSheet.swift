import SwiftUI

/// Edit-in-place form for an existing goal. Lets the user tweak the name,
/// emoji, target amount and target date without losing accumulated deposits.
struct EditGoalSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    let original: Goal

    @State private var emoji: String
    @State private var lastValidEmoji: String
    @State private var name: String
    @State private var targetText: String
    @State private var targetDate: Date
    @State private var confirmingDelete = false

    init(goal: Goal) {
        self.original = goal
        self._emoji = State(initialValue: goal.emoji)
        self._lastValidEmoji = State(initialValue: goal.emoji)
        self._name = State(initialValue: goal.name)
        self._targetText = State(initialValue: String(format: "%.0f", goal.targetAmount))
        self._targetDate = State(initialValue: goal.targetDate)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                topbar
                emojiField
                field(label: "Name") {
                    TextField("e.g. Tokyo trip", text: $name)
                        .font(AppFont.body)
                }
                field(label: "Target amount") {
                    HStack {
                        Text(Money.symbol).foregroundColor(Theme.Palette.inkSoft)
                        TextField("500", text: $targetText)
                            .keyboardType(.decimalPad)
                            .font(AppFont.body)
                    }
                }
                if belowDepositedFloor {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Palette.red)
                        Text("Target can't be less than \(Money.format(original.currentAmount)) already saved.")
                            .font(AppFont.text(12))
                            .foregroundColor(Theme.Palette.red)
                    }
                }
                field(label: "Target date") {
                    DatePicker("", selection: $targetDate,
                               in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                }
                deleteButton
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .alert("Delete this goal?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                container.deleteGoal(original.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deposits and progress will be removed.")
        }
    }

    private var topbar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .foregroundColor(Theme.Palette.inkSoft)
            Spacer()
            Text("Edit goal").font(AppFont.headline)
            Spacer()
            Button("Save", action: save)
                .foregroundColor(canSave ? Theme.Palette.gold : Theme.Palette.inkMute)
                .fontWeight(.semibold)
                .disabled(!canSave)
        }
        .font(AppFont.text(14, weight: .medium))
        .padding(.top, 18)
    }

    private var emojiField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Emoji")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6).textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            HStack(spacing: 8) {
                EmojiTextField(text: $emoji, fontSize: 32)
                    .frame(width: 56, height: 56)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
                    .onChange(of: emoji) { newValue in
                        let cleaned = EmojiInput.sanitize(newValue)
                        if !cleaned.isEmpty {
                            if cleaned != newValue { emoji = cleaned }
                            lastValidEmoji = cleaned
                        } else if !newValue.isEmpty {
                            emoji = lastValidEmoji
                        }
                    }
                Text("Tap to change. Pick anything that fits this goal.")
                    .font(AppFont.text(12))
                    .foregroundColor(Theme.Palette.inkSoft)
            }
        }
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6).textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            content()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
        }
    }

    private var deleteButton: some View {
        Button {
            confirmingDelete = true
        } label: {
            Text("Delete this goal")
                .font(AppFont.text(13, weight: .semibold))
                .foregroundColor(Theme.Palette.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.redSoft))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.red.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plainTappable)
        .padding(.top, 6)
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let newTarget = Money.parseAmount(targetText) else { return false }
        return !trimmedName.isEmpty
            && !trimmedEmoji.isEmpty
            && newTarget >= original.currentAmount
    }

    /// True once the user has typed a target lower than what's already been
    /// deposited into this goal. Drives the inline warning under the target
    /// field so they understand why Save is disabled.
    private var belowDepositedFloor: Bool {
        guard let newTarget = Money.parseAmount(targetText) else { return false }
        return newTarget < original.currentAmount
    }

    private func save() {
        guard let newTarget = Money.parseAmount(targetText) else { return }
        guard newTarget >= original.currentAmount else { return }
        var updated = original
        updated.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        updated.emoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.targetAmount = newTarget
        updated.targetDate = targetDate
        // Editing a Past Win such that it's no longer 100% funded should
        // bring it back to the active Goals tab so the user can keep
        // depositing toward the new target.
        if updated.isArchived, updated.currentAmount < updated.targetAmount {
            updated.archivedAt = nil
        }
        container.saveGoal(updated)
        dismiss()
    }
}
