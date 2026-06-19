import SwiftUI

/// A display currency. Local-only (never synced); only controls the symbol /
/// formatting the app shows. We store the ISO **code** (e.g. "INR"), never the
/// symbol, because many currencies share a symbol ($, kr, Rs, CFA). The selected
/// code is persisted in UserDefaults via `Money.currencyCode`.
struct Currency: Identifiable, Equatable {
    let code: String    // ISO 4217, e.g. "INR"
    let symbol: String  // display only, e.g. "₹"
    let name: String    // e.g. "Indian Rupee"
    var id: String { code }
}

enum Currencies {
    /// Curated default picker (~58), majors first then grouped by region.
    /// Covers essentially all major App Store markets plus the largest emerging
    /// markets. Anything outside this is still reachable via search (`all`).
    static let common: [Currency] = [
        // Majors
        Currency(code: "USD", symbol: "$",    name: "US Dollar"),
        Currency(code: "EUR", symbol: "€",    name: "Euro"),
        Currency(code: "GBP", symbol: "£",    name: "British Pound"),
        Currency(code: "CHF", symbol: "Fr",   name: "Swiss Franc"),
        Currency(code: "CAD", symbol: "C$",   name: "Canadian Dollar"),
        Currency(code: "AUD", symbol: "A$",   name: "Australian Dollar"),
        Currency(code: "NZD", symbol: "NZ$",  name: "New Zealand Dollar"),
        // Europe
        Currency(code: "SEK", symbol: "kr",   name: "Swedish Krona"),
        Currency(code: "NOK", symbol: "kr",   name: "Norwegian Krone"),
        Currency(code: "DKK", symbol: "kr",   name: "Danish Krone"),
        Currency(code: "PLN", symbol: "zł",   name: "Polish Złoty"),
        Currency(code: "CZK", symbol: "Kč",   name: "Czech Koruna"),
        Currency(code: "HUF", symbol: "Ft",   name: "Hungarian Forint"),
        Currency(code: "RON", symbol: "lei",  name: "Romanian Leu"),
        Currency(code: "BGN", symbol: "лв",   name: "Bulgarian Lev"),
        Currency(code: "ISK", symbol: "kr",   name: "Icelandic Króna"),
        Currency(code: "TRY", symbol: "₺",    name: "Turkish Lira"),
        Currency(code: "UAH", symbol: "₴",    name: "Ukrainian Hryvnia"),
        // East Asia
        Currency(code: "JPY", symbol: "¥",    name: "Japanese Yen"),
        Currency(code: "CNY", symbol: "CN¥",  name: "Chinese Yuan"),
        Currency(code: "HKD", symbol: "HK$",  name: "Hong Kong Dollar"),
        Currency(code: "TWD", symbol: "NT$",  name: "Taiwan Dollar"),
        Currency(code: "KRW", symbol: "₩",    name: "South Korean Won"),
        Currency(code: "SGD", symbol: "S$",   name: "Singapore Dollar"),
        // South Asia
        Currency(code: "INR", symbol: "₹",    name: "Indian Rupee"),
        Currency(code: "PKR", symbol: "₨",    name: "Pakistani Rupee"),
        Currency(code: "BDT", symbol: "৳",    name: "Bangladeshi Taka"),
        Currency(code: "LKR", symbol: "Rs",   name: "Sri Lankan Rupee"),
        Currency(code: "NPR", symbol: "Rs",   name: "Nepalese Rupee"),
        // Southeast Asia
        Currency(code: "THB", symbol: "฿",    name: "Thai Baht"),
        Currency(code: "VND", symbol: "₫",    name: "Vietnamese Dong"),
        Currency(code: "MYR", symbol: "RM",   name: "Malaysian Ringgit"),
        Currency(code: "IDR", symbol: "Rp",   name: "Indonesian Rupiah"),
        Currency(code: "PHP", symbol: "₱",    name: "Philippine Peso"),
        // Middle East
        Currency(code: "AED", symbol: "AED",  name: "UAE Dirham"),
        Currency(code: "SAR", symbol: "SAR",  name: "Saudi Riyal"),
        Currency(code: "QAR", symbol: "QAR",  name: "Qatari Riyal"),
        Currency(code: "KWD", symbol: "KWD",  name: "Kuwaiti Dinar"),
        Currency(code: "BHD", symbol: "BHD",  name: "Bahraini Dinar"),
        Currency(code: "OMR", symbol: "OMR",  name: "Omani Rial"),
        Currency(code: "ILS", symbol: "₪",    name: "Israeli New Shekel"),
        // Latin America
        Currency(code: "BRL", symbol: "R$",   name: "Brazilian Real"),
        Currency(code: "MXN", symbol: "Mex$", name: "Mexican Peso"),
        Currency(code: "ARS", symbol: "AR$",  name: "Argentine Peso"),
        Currency(code: "CLP", symbol: "CLP$", name: "Chilean Peso"),
        Currency(code: "COP", symbol: "COL$", name: "Colombian Peso"),
        Currency(code: "PEN", symbol: "S/",   name: "Peruvian Sol"),
        Currency(code: "UYU", symbol: "$U",   name: "Uruguayan Peso"),
        // Africa
        Currency(code: "ZAR", symbol: "R",    name: "South African Rand"),
        Currency(code: "NGN", symbol: "₦",    name: "Nigerian Naira"),
        Currency(code: "KES", symbol: "KSh",  name: "Kenyan Shilling"),
        Currency(code: "GHS", symbol: "₵",    name: "Ghanaian Cedi"),
        Currency(code: "EGP", symbol: "E£",   name: "Egyptian Pound"),
        Currency(code: "MAD", symbol: "DH",   name: "Moroccan Dirham"),
        Currency(code: "TZS", symbol: "TSh",  name: "Tanzanian Shilling"),
        Currency(code: "UGX", symbol: "USh",  name: "Ugandan Shilling"),
        Currency(code: "XOF", symbol: "CFA",  name: "West African CFA Franc"),
        Currency(code: "XAF", symbol: "CFA",  name: "Central African CFA Franc"),
    ]

    private static let curatedByCode: [String: Currency] =
        Dictionary(uniqueKeysWithValues: common.map { ($0.code, $0) })

    /// Every common ISO-4217 currency iOS knows (curated symbol/name where we
    /// have it, system-derived otherwise). Backs "search any currency".
    static let all: [Currency] = {
        Locale.commonISOCurrencyCodes
            .map { currency(for: $0) }
            .sorted { $0.code < $1.code }
    }()

    static func currency(for code: String) -> Currency {
        curatedByCode[code] ?? Currency(
            code: code,
            symbol: derivedSymbol(code),
            name: Locale.current.localizedString(forCurrencyCode: code) ?? code
        )
    }

    static func symbol(for code: String) -> String { currency(for: code).symbol }

    private static func derivedSymbol(_ code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.currencySymbol ?? code
    }

    /// Best guess from the device region (effectively "where they are").
    static func detected() -> Currency {
        let code = Locale.current.currency?.identifier ?? "USD"
        return currency(for: code)
    }

    /// Common list, with `code` pinned on top if it isn't already common.
    static func pickerList(including code: String) -> [Currency] {
        common.contains { $0.code == code } ? common : [currency(for: code)] + common
    }

    /// Search across every ISO currency by code or name.
    static func search(_ q: String) -> [Currency] {
        let t = q.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty else { return [] }
        return all.filter {
            $0.code.lowercased().contains(t) || $0.name.lowercased().contains(t)
        }
    }
}

/// Currency chooser used both as the onboarding confirm (full-screen, before
/// the Try-It-Live ramen) and from You settings. Shows the curated list by
/// default and searches all ISO currencies when typing. Confirming sets
/// `container.currencyCode`, which updates `Money` and refreshes every amount.
struct CurrencyPickerSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    var title: String = "Currency"
    var subtitle: String = "Show every amount in this currency."
    var cta: String = "Done"
    /// Pre-selected: the detected currency for onboarding, the current one from settings.
    var initialCode: String = Money.currencyCode
    /// When set, called after a currency is chosen (the onboarding step uses
    /// this to advance); otherwise the view dismisses (sheet/cover usage).
    var onConfirm: (() -> Void)? = nil
    /// When set, shows a back bar at the top (onboarding step); nil hides it.
    var onBack: (() -> Void)? = nil

    @State private var selected: String = Money.currencyCode
    @State private var query: String = ""

    private var list: [Currency] {
        query.trimmingCharacters(in: .whitespaces).isEmpty
            ? Currencies.pickerList(including: selected)
            : Currencies.search(query)
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                if let onBack {
                    BackBar(onBack: onBack, pageLabel: "Currency")
                }
                Text(title)
                    .font(AppFont.display(28, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                    .padding(.top, 8)
                Text(subtitle)
                    .font(AppFont.callout)
                    .foregroundColor(Theme.Palette.inkSoft)

                searchField

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        if list.isEmpty {
                            Text("No currency matches “\(query)”.")
                                .font(AppFont.text(13))
                                .foregroundColor(Theme.Palette.inkMute)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(list) { row($0) }
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.immediately)

                PrimaryButton(title: cta) {
                    container.currencyCode = selected
                    Money.currencyConfirmed = true
                    if let onConfirm { onConfirm() } else { dismiss() }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .onAppear { selected = initialCode }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Palette.inkMute)
            TextField("Search 150+ currencies", text: $query)
                .font(AppFont.text(15))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Palette.inkMute)
                }
                .buttonStyle(.plainTappable)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.bgCream))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.line, lineWidth: 1))
    }

    private func row(_ c: Currency) -> some View {
        let isOn = selected == c.code
        return Button { selected = c.code } label: {
            HStack(spacing: 14) {
                Text(c.symbol)
                    .font(AppFont.text(15, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.goldPastel))
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name)
                        .font(AppFont.text(15, weight: .semibold))
                        .foregroundColor(Theme.Palette.ink)
                    Text(c.code)
                        .font(AppFont.text(12, weight: .medium))
                        .foregroundColor(Theme.Palette.inkSoft)
                }
                Spacer()
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.Palette.gold)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(isOn ? Theme.Palette.goldLight : Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(isOn ? Theme.Palette.gold : Theme.Palette.line, lineWidth: isOn ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
    }
}

/// Onboarding step: pick the display currency on its own screen, right before
/// the first (fake) log, so every amount from there on shows correctly.
struct CurrencyScreen: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        CurrencyPickerSheet(
            title: "Pick your currency",
            subtitle: "We'll show every amount in this. You can change it anytime in You.",
            cta: "That's my currency",
            initialCode: Currencies.detected().code,
            onConfirm: { container.advanceOnboarding(to: .tryLive) },
            onBack: { container.advanceOnboarding(to: .backTapTeaser) }
        )
    }
}

/// Approximate USD exchange rates, baked in so currency conversion works
/// offline. Precision isn't critical: converted goal amounts are rounded to a
/// clean number for display, not used for real money (Apple handles real
/// charges). Swap for a live feed later if exact rates are ever needed.
enum CurrencyRates {
    static let perUSD: [String: Double] = [
        "USD": 1, "EUR": 0.92, "GBP": 0.79, "CHF": 0.88, "CAD": 1.36, "AUD": 1.52,
        "NZD": 1.64, "SEK": 10.5, "NOK": 10.7, "DKK": 6.9, "PLN": 4.0, "CZK": 23,
        "HUF": 360, "RON": 4.6, "BGN": 1.8, "ISK": 138, "TRY": 32, "UAH": 40,
        "JPY": 150, "CNY": 7.2, "HKD": 7.8, "TWD": 32, "KRW": 1350, "SGD": 1.35,
        "INR": 83, "PKR": 280, "BDT": 110, "LKR": 300, "NPR": 133, "THB": 36,
        "VND": 25000, "MYR": 4.7, "IDR": 15800, "PHP": 57, "AED": 3.67, "SAR": 3.75,
        "QAR": 3.64, "KWD": 0.31, "BHD": 0.38, "OMR": 0.385, "ILS": 3.7, "BRL": 5.0,
        "MXN": 17, "ARS": 900, "CLP": 950, "COP": 4000, "PEN": 3.7, "UYU": 39,
        "ZAR": 18.5, "NGN": 1500, "KES": 130, "GHS": 15, "EGP": 48, "MAD": 10,
        "TZS": 2600, "UGX": 3800, "XOF": 600, "XAF": 600,
    ]

    static func rate(_ code: String) -> Double { perUSD[code] ?? 1 }

    /// Convert an amount from one currency to another via USD.
    static func convert(_ amount: Double, from: String, to: String) -> Double {
        guard from != to else { return amount }
        return (amount / rate(from)) * rate(to)
    }

    /// Round to ~2 significant figures so converted amounts read as clean
    /// numbers (e.g. $450 → ₹37,000, not ₹37,350).
    static func roundNice(_ v: Double) -> Double {
        guard v.isFinite, v > 0 else { return v }
        let mag = pow(10, floor(log10(v)))
        let step = max(mag / 10, 1)
        return (v / step).rounded() * step
    }
}
