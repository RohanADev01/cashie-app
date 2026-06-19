import SwiftUI

struct AddGoalSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss

    @State private var emoji: String = "🎯"
    @State private var lastValidEmoji: String = "🎯"
    @State private var name: String = ""
    @State private var targetText: String = ""
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var isCustom: Bool = false

    /// Quick-pick deadlines. Tapping one snaps `targetDate`; the date
    /// picker stays editable so users can fine-tune.
    private enum DeadlinePreset: Hashable {
        case weeks(Int)
        case months(Int)

        var label: String {
            switch self {
            case .weeks(let n): return "\(n) wk\(n == 1 ? "" : "s")"
            case .months(let n): return "\(n) mo"
            }
        }

        func date(from base: Date = Date()) -> Date {
            let cal = Calendar.current
            switch self {
            case .weeks(let n):
                return cal.date(byAdding: .day, value: n * 7, to: base) ?? base
            case .months(let n):
                return cal.date(byAdding: .month, value: n, to: base) ?? base
            }
        }
    }

    private let deadlinePresets: [DeadlinePreset] = [
        .weeks(1), .weeks(2), .weeks(3),
        .months(1), .months(3), .months(6), .months(12), .months(24),
    ]

    private let templates: [(emoji: String, label: String)] = [
        ("✈️", "Trip"),
        ("🎮", "Big purchase"),
        ("🏡", "Moving out"),
        ("🚑", "Emergency fund"),
        ("🎓", "Course"),
        ("✦", "Custom"),
    ]

    /// Common picks for the custom-goal icon picker. Keep the set tight so
    /// the chooser stays glanceable; the freeform field handles the rest.
    private let iconChoices: [String] = [
        "🎯", "💸", "🛻", "🛏️", "💍", "💻", "📷", "🎧",
        "🚗", "🛵", "🐶", "🌱", "🏝️", "🎟️", "💪", "✦",
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Palette.inkSoft)
                    Spacer()
                    Text("New goal").font(AppFont.headline)
                    Spacer()
                    Button("Save", action: save)
                        .foregroundColor(canSave ? Theme.Palette.gold : Theme.Palette.inkMute)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
                .font(AppFont.text(14, weight: .medium))
                .padding(.top, 18)

                EmphasizedHeadline(
                    raw: "What are you <em>saving for?</em>",
                    font: AppFont.display(34, weight: .bold)
                )
                Text("Pick a template or roll your own.")
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(templates, id: \.label) { t in
                        Button {
                            emoji = t.emoji
                            name = t.label == "Custom" ? "" : t.label
                            isCustom = (t.label == "Custom")
                        } label: {
                            HStack(spacing: 8) {
                                Text(t.emoji)
                                Text(t.label).font(AppFont.text(13, weight: .medium))
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected(t) ? Theme.Palette.goldLight : Theme.Palette.bgCream))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected(t) ? Theme.Palette.gold : Theme.Palette.line, lineWidth: 1))
                            .foregroundColor(Theme.Palette.ink)
                        }
                        .buttonStyle(.plainTappable)
                    }
                }

                if isCustom {
                    iconPicker
                }

                field(label: "What's it called?") {
                    TextField("e.g. Tokyo 2026", text: $name).font(AppFont.body)
                }

                field(label: "How much?") {
                    HStack {
                        Text(Money.symbol).foregroundColor(Theme.Palette.inkSoft)
                        TextField("500", text: $targetText)
                            .keyboardType(.numberPad)
                            .font(AppFont.body)
                    }
                }

                deadlineSection

                paceCard
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(AppFont.text(11, weight: .semibold))
                .tracking(0.6).textCase(.uppercase).foregroundColor(Theme.Palette.inkSoft)
            content()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
        }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pick an icon")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                ForEach(iconChoices, id: \.self) { glyph in
                    Button { emoji = glyph } label: {
                        Text(glyph)
                            .font(.system(size: 22))
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(emoji == glyph ? Theme.Palette.goldLight : Theme.Palette.bgCream)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(emoji == glyph ? Theme.Palette.gold : Theme.Palette.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plainTappable)
                }
            }
            HStack(spacing: 10) {
                Text("Or type one:")
                    .font(AppFont.text(12))
                    .foregroundColor(Theme.Palette.inkSoft)
                EmojiTextField(text: $emoji, placeholder: "✦", fontSize: 22)
                    .frame(width: 56, height: 38)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
                    .onChange(of: emoji) { newValue in
                        // Allow emoji through; if the user types plain text
                        // we silently revert to the previous emoji instead
                        // of wiping the field, so the emoji keyboard /
                        // paste flow still feels responsive.
                        let cleaned = EmojiInput.sanitize(newValue)
                        if !cleaned.isEmpty {
                            if cleaned != newValue { emoji = cleaned }
                            lastValidEmoji = cleaned
                        } else if !newValue.isEmpty {
                            emoji = lastValidEmoji
                        }
                    }
            }
        }
    }

    private func isSelected(_ template: (emoji: String, label: String)) -> Bool {
        if template.label == "Custom" { return isCustom }
        return !isCustom && name == template.label
    }

    /// "By when?" - quick chips snap to a preset offset, plus a date
     /// picker for custom dates. Both edit the same `targetDate`, so chips
    /// and picker stay in sync.
    private var deadlineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By when?")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6).textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            FlowLayout(spacing: 6) {
                ForEach(deadlinePresets, id: \.self) { preset in
                    Button { targetDate = preset.date() } label: {
                        Text(preset.label)
                            .font(AppFont.text(13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(matchesPreset(preset) ? Theme.Palette.goldLight : Theme.Palette.bgCream))
                            .overlay(Capsule().stroke(matchesPreset(preset) ? Theme.Palette.gold : Theme.Palette.line, lineWidth: 1))
                            .foregroundColor(Theme.Palette.ink)
                    }
                    .buttonStyle(.plainTappable)
                }
            }
            DatePicker("", selection: $targetDate, in: Date()..., displayedComponents: .date)
                .labelsHidden()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.line, lineWidth: 1))
        }
    }

    /// True if `targetDate` (day-resolution) lines up with the date this
    /// preset would produce from today.
    private func matchesPreset(_ preset: DeadlinePreset) -> Bool {
        let cal = Calendar.current
        return cal.isDate(preset.date(), inSameDayAs: targetDate)
    }

    private var paceCard: some View {
        let target = Money.parseAmount(targetText) ?? 0
        let weeks = max(1, weeksUntilTarget)
        let weekly = target / Double(weeks)
        return VStack(alignment: .leading, spacing: 8) {
            Text("At that pace…")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
            Text("~\(Money.symbol)\(Int(weekly.rounded())) / week")
                .font(AppFont.display(40, weight: .heavy))
                .foregroundColor(Theme.Palette.ink)
            Text(paceAnchor(weekly: weekly))
                .font(AppFont.text(13))
                .foregroundColor(Theme.Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    /// Anchors the weekly pace against a category the user actually spends in.
    /// Returns "" when there isn't enough real data to be meaningful, and the
    /// caller renders nothing fake in its place.
    private func paceAnchor(weekly: Double) -> String {
        guard weekly > 0 else { return "Set a target to see what it costs per week." }

        // Average weekly spend per category, derived from this month's logs.
        let cal = Calendar.current
        let daysIn = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        let weeksIn = max(1.0, Double(daysIn) / 7.0)

        let candidates: [(SpendCategory, Double)] = SpendCategory.allCases
            .filter { $0 != .income }
            .compactMap { cat in
                let monthly = container.monthSpend(in: cat)
                guard monthly > 0 else { return nil }
                return (cat, monthly / weeksIn)
            }

        // Pick the user's biggest weekly category and express the goal as a
        // share of it. If they spend $40 on coffee a week and the goal needs
        // $20/week, that's "half a week of coffee."
        guard let top = candidates.max(by: { $0.1 < $1.1 }), top.1 > 0 else {
            return "Whatever fits in your budget. We'll track the pace."
        }
        let ratio = weekly / top.1
        let label = top.0.label.lowercased()
        switch ratio {
        case ..<0.25: return "≈ a quarter of your weekly \(label) spend."
        case ..<0.5:  return "≈ half a week of \(label)."
        case ..<1:    return "Less than a week of \(label)."
        case 1...1.2: return "≈ a full week of \(label)."
        default:
            let weeks = ratio.rounded()
            return "≈ \(Int(weeks)) weeks of \(label) spend."
        }
    }

    /// Whole weeks between today and the chosen target date, floored at 1
    /// so the pace card never divides by zero.
    private var weeksUntilTarget: Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.day], from: Date(), to: targetDate)
        let days = max(1, comps.day ?? 7)
        return max(1, Int((Double(days) / 7.0).rounded(.up)))
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty
            && !trimmedEmoji.isEmpty
            && Money.parseAmount(targetText) != nil
            && targetDate > Date()
    }

    private func save() {
        guard let target = Money.parseAmount(targetText) else { return }
        let goal = Goal(
            emoji: emoji.trimmingCharacters(in: .whitespacesAndNewlines),
            name: String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)),
            targetAmount: target,
            currentAmount: 0,
            targetDate: targetDate
        )
        container.saveGoal(goal)
        dismiss()
    }
}
