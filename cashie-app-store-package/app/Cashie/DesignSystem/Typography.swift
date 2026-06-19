import SwiftUI

/// Cashie typography. Maps the CSS tokens defined in the prototype.
///
/// Display = Barlow Condensed (Google Fonts). Falls back to a condensed system
/// face when the .ttf files have not yet been added to Resources/Fonts.
/// Text = Inter (Google Fonts). Falls back to SF Pro.
///
/// To enable the custom faces, drop the .ttf files into Resources/Fonts and
/// re-run scripts/gen_pbxproj.py, Info.plist already lists them.
enum AppFont {

    // MARK: - Names registered in Info.plist
    private enum Names {
        static let displayRegular = "BarlowCondensed-Regular"
        static let displayMedium = "BarlowCondensed-Medium"
        static let displaySemibold = "BarlowCondensed-SemiBold"
        static let displayBold = "BarlowCondensed-Bold"
        static let displayExtraBold = "BarlowCondensed-ExtraBold"
        static let displayItalic = "BarlowCondensed-Italic"
        static let displayMediumItalic = "BarlowCondensed-MediumItalic"
        static let displaySemiboldItalic = "BarlowCondensed-SemiBoldItalic"
        static let displayBoldItalic = "BarlowCondensed-BoldItalic"
        static let displayExtraBoldItalic = "BarlowCondensed-ExtraBoldItalic"

        static let textRegular = "Inter-Regular"
        static let textMedium = "Inter-Medium"
        static let textSemibold = "Inter-SemiBold"
        static let textBold = "Inter-Bold"
        static let textItalic = "Inter-Italic"
    }

    // MARK: - Display (Barlow Condensed)

    static func display(_ size: CGFloat,
                        weight: Font.Weight = .heavy,
                        italic: Bool = false) -> Font {
        let name = displayName(for: weight, italic: italic)
        if isFontAvailable(name) {
            return .custom(name, size: size)
        }
        // Fallback: condensed SF Pro with adjustment so layout stays close.
        var font: Font = .system(size: size, weight: weight, design: .default)
        if italic { font = font.italic() }
        return font
    }

    private static func displayName(for weight: Font.Weight, italic: Bool) -> String {
        switch (weight, italic) {
        case (.regular, false): return Names.displayRegular
        case (.regular, true): return Names.displayItalic
        case (.medium, false): return Names.displayMedium
        case (.medium, true): return Names.displayMediumItalic
        case (.semibold, false): return Names.displaySemibold
        case (.semibold, true): return Names.displaySemiboldItalic
        case (.bold, false): return Names.displayBold
        case (.bold, true): return Names.displayBoldItalic
        case (.heavy, false): return Names.displayExtraBold
        case (.heavy, true): return Names.displayExtraBoldItalic
        case (.black, _): return italic ? Names.displayExtraBoldItalic : Names.displayExtraBold
        default: return italic ? Names.displayItalic : Names.displayRegular
        }
    }

    // MARK: - Text (Inter)

    static func text(_ size: CGFloat,
                     weight: Font.Weight = .regular,
                     italic: Bool = false) -> Font {
        let name = textName(for: weight, italic: italic)
        if isFontAvailable(name) {
            return .custom(name, size: size)
        }
        var font: Font = .system(size: size, weight: weight, design: .default)
        if italic { font = font.italic() }
        return font
    }

    private static func textName(for weight: Font.Weight, italic: Bool) -> String {
        if italic { return Names.textItalic }
        switch weight {
        case .medium: return Names.textMedium
        case .semibold: return Names.textSemibold
        case .bold, .heavy, .black: return Names.textBold
        default: return Names.textRegular
        }
    }

    // MARK: - Token aliases (match the CSS scale)
    static let displayXL = display(72)             // hero $ amounts
    static let displayL = display(56)              // balance, big number
    static let displayM = display(40)              // welcome-hook, paywall-h1
    static let displayS = display(30, weight: .bold) // quiz-q, reveal headline
    static let displayItalicM = display(40, italic: true)
    static let displayItalicS = display(30, italic: true)

    static let largeTitle = text(28, weight: .bold)
    static let title1 = text(22, weight: .bold)
    static let title2 = text(20, weight: .bold)
    static let title3 = text(18, weight: .semibold)
    static let headline = text(17, weight: .semibold)
    static let body = text(17, weight: .regular)
    static let callout = text(16, weight: .regular)
    static let subhead = text(15, weight: .medium)
    static let footnote = text(13, weight: .medium)
    static let caption1 = text(12, weight: .semibold)
    static let caption2 = text(11, weight: .semibold)
    static let micro = text(10, weight: .bold)

    // MARK: - Availability cache
    private static var availableCache: [String: Bool] = [:]

    static func isFontAvailable(_ name: String) -> Bool {
        if let cached = availableCache[name] { return cached }
        let ok = UIFont(name: name, size: 12) != nil
        availableCache[name] = ok
        return ok
    }
}

// MARK: - View modifiers for common token applications

extension View {
    func displayXL() -> some View { font(AppFont.displayXL) }
    func displayL() -> some View { font(AppFont.displayL) }
    func displayM() -> some View { font(AppFont.displayM) }
    func displayS() -> some View { font(AppFont.displayS) }
    func largeTitle() -> some View { font(AppFont.largeTitle) }
    func title1() -> some View { font(AppFont.title1) }
    func title2() -> some View { font(AppFont.title2) }
    func title3() -> some View { font(AppFont.title3) }
    func headline() -> some View { font(AppFont.headline) }
    func body_() -> some View { font(AppFont.body) }
    func callout() -> some View { font(AppFont.callout) }
    func subhead() -> some View { font(AppFont.subhead) }
    func footnote() -> some View { font(AppFont.footnote) }
    func caption1() -> some View { font(AppFont.caption1) }
    func caption2() -> some View { font(AppFont.caption2) }
    func micro() -> some View { font(AppFont.micro).tracking(1) }
}

extension Text {
    /// Uppercase tracking that mimics the CSS letter-spacing on micro labels.
    func kicker() -> Text {
        self.tracking(1.5)
    }
}
