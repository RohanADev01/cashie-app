import SwiftUI

/// Currency formatter used app-wide. The display currency is local-only
/// (UserDefaults, never synced); see `currencyCode` and `CurrencyPickerSheet`.
enum Money {
    private static let codeKey = "cashie.currencyCode"
    private static let confirmedKey = "cashie.currencyConfirmed"

    /// ISO 4217 code the app displays in. Defaults to USD so early onboarding
    /// shows "$"; the user confirms their real currency just before the
    /// Try-It-Live log. Setting it invalidates the cached formatters.
    static var currencyCode: String {
        get { UserDefaults.standard.string(forKey: codeKey) ?? "USD" }
        set {
            UserDefaults.standard.set(newValue, forKey: codeKey)
            cache = nil
        }
    }

    /// Whether the user has confirmed a currency yet (gates the onboarding prompt).
    static var currencyConfirmed: Bool {
        get { UserDefaults.standard.bool(forKey: confirmedKey) }
        set { UserDefaults.standard.set(newValue, forKey: confirmedKey) }
    }

    /// The current symbol, e.g. "$", "₹", "£".
    static var symbol: String { Currencies.symbol(for: currencyCode) }

    private static var cache: (code: String, whole: NumberFormatter, cents: NumberFormatter)?

    private static func make(_ code: String, fraction: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        // Force our clean symbol so a non-matching device locale never shows a
        // disambiguated symbol like "US$".
        f.currencySymbol = Currencies.symbol(for: code)
        f.maximumFractionDigits = fraction
        f.minimumFractionDigits = fraction
        return f
    }

    private static func formatters() -> (NumberFormatter, NumberFormatter) {
        let code = currencyCode
        if let c = cache, c.code == code { return (c.whole, c.cents) }
        let whole = make(code, fraction: 0)
        let cents = make(code, fraction: 2)
        cache = (code, whole, cents)
        return (whole, cents)
    }

    static func format(_ value: Double, cents: Bool = false) -> String {
        // Non-finite values (NaN / Inf) make NumberFormatter return nil, and the
        // old `Int(value)` fallback then crashed (Int(.infinity) is fatal in
        // Swift). Short-circuit them to a safe zero. Callers shouldn't produce
        // these, but this is the app-wide last line of defense.
        guard value.isFinite else { return symbol + "0" }
        let (whole, centsF) = formatters()
        return (cents ? centsF : whole).string(from: NSNumber(value: value)) ?? (symbol + "0")
    }

    /// Parses user-entered currency text into a clean, safe amount. Returns nil
    /// unless the text is a finite, positive number within a sane ceiling.
    /// Centralising this keeps NaN/Inf (e.g. a pasted "inf" or "1e400") and
    /// absurd values out of the data model, where they would later crash a
    /// layout calc or an `Int(...)` conversion.
    static func parseAmount(_ text: String) -> Double? {
        guard let v = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              v.isFinite, v > 0, v <= 1_000_000_000 else { return nil }
        return v
    }

    /// Renders an amount as plain keypad text ("12" or "12.50"), no currency
    /// symbol. Used to seed the Quick Log keypad from a prefilled amount.
    static func plainString(_ amount: Double) -> String {
        guard amount.isFinite, amount > 0 else { return "" }
        if amount == amount.rounded(.towardZero) { return String(Int(amount)) }
        return String(format: "%.2f", amount)
    }
}

/// Drop-in replacement for `.buttonStyle(.plain)` that hit-tests the whole
/// label rectangle. Plain SwiftUI plain buttons only register taps on the
/// visible content, so HStacks-with-Spacer or ZStacks-with-gradient labels
/// have transparent dead zones. Use `.buttonStyle(.plainTappable)`
/// everywhere a Button wraps a structural layout.
struct TappablePlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

extension ButtonStyle where Self == TappablePlainButtonStyle {
    static var plainTappable: TappablePlainButtonStyle { TappablePlainButtonStyle() }
}

extension View {
    /// "Tap anywhere to continue" for a linear onboarding screen: any tap not
    /// consumed by a control (button, field, etc.) runs `action`, the same
    /// forward step the primary CTA triggers. Controls on top keep working
    /// because they consume their own taps; scrolling is unaffected (a drag is
    /// not a tap). Pass `enabled: false` to suspend it (e.g. while a screen's
    /// entrance animation is still playing). Reserved for screens with a single
    /// forward CTA, never for ones where a tap selects (quiz, pickers, paywall).
    @ViewBuilder
    func tapAnywhereToContinue(enabled: Bool = true, perform action: @escaping () -> Void) -> some View {
        if enabled {
            self.contentShape(Rectangle()).onTapGesture(perform: action)
        } else {
            self
        }
    }
}

/// A sticky decorative blob that mimics the radial gradients used on
/// onboarding screens (top-right, bottom-left, etc.).
struct GoldBlob: View {
    var color: Color = Theme.Palette.gold
    var alignment: Alignment = .topTrailing
    var size: CGFloat = 420
    var intensity: Double = 0.12

    var body: some View {
        ZStack(alignment: alignment) {
            Color.clear
            color.opacity(intensity)
                .frame(width: size, height: size)
                .blur(radius: 90)
                .offset(
                    x: alignment.horizontal == .trailing ? size * 0.25 : -size * 0.25,
                    y: alignment.vertical == .top ? -size * 0.25 : size * 0.25
                )
        }
        .allowsHitTesting(false)
    }
}

/// Pill button that fills the width, primary CTA across the app.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var trailingArrow: Bool = true
    var background: Color = Theme.Palette.ink
    var foreground: Color = .white
    /// When false the button is non-tappable and visibly dimmed.
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(AppFont.text(15, weight: .semibold))
                if trailingArrow {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.pill)
                    .fill(background)
            )
        }
        .buttonStyle(.plainTappable)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Ghost / text-only secondary button used on welcome screens.
struct GhostButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.text(11, weight: .medium))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundColor(Theme.Palette.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plainTappable)
    }
}

struct Pill: View {
    let text: String
    var background: Color = Theme.Palette.ink
    var foreground: Color = .white

    var body: some View {
        Text(text)
            .font(AppFont.text(10, weight: .semibold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundColor(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(background)
            )
    }
}

/// Card container used across the app.
struct CashCard<Content: View>: View {
    var background: Color = Theme.Palette.bgCream
    var cornerRadius: CGFloat = Theme.Radius.lg
    var border: Color? = Theme.Palette.line
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(border ?? .clear, lineWidth: 1)
            )
    }
}

/// Top header used on inner screens, back button on the left, page indicator on right.
struct BackBar: View {
    var onBack: () -> Void
    var pageLabel: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Back")
                        .font(AppFont.text(11, weight: .semibold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                }
                .foregroundColor(Theme.Palette.inkSoft)
            }
            .buttonStyle(.plainTappable)
            Spacer()
            if let pageLabel {
                Text(pageLabel)
                    .font(AppFont.text(11, weight: .medium))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Palette.inkMute)
            }
            if let trailing { trailing }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }
}

/// Renders an italic em phrase inside a longer headline by wrapping `<em>...</em>`.
/// In the prototype, `<em>` is colored gold, we match that.
struct EmphasizedHeadline: View {
    /// String like "You're not <em>bad</em> with money"
    let raw: String
    var font: Font
    var emColor: Color = Theme.Palette.gold

    var body: some View {
        let parts = parse(raw)
        var combined = Text("")
        for (text, isEm) in parts {
            let chunk: Text
            if isEm {
                chunk = Text(text).italic().foregroundColor(emColor)
            } else {
                chunk = Text(text)
            }
            combined = combined + chunk
        }
        return combined.font(font)
    }

    private func parse(_ s: String) -> [(String, Bool)] {
        var results: [(String, Bool)] = []
        var rest = Substring(s)
        while !rest.isEmpty {
            if let openRange = rest.range(of: "<em>"),
               let closeRange = rest.range(of: "</em>") {
                let pre = rest[rest.startIndex..<openRange.lowerBound]
                if !pre.isEmpty { results.append((String(pre), false)) }
                let mid = rest[openRange.upperBound..<closeRange.lowerBound]
                if !mid.isEmpty { results.append((String(mid), true)) }
                rest = rest[closeRange.upperBound..<rest.endIndex]
            } else {
                results.append((String(rest), false))
                break
            }
        }
        return results
    }
}
