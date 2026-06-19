import Foundation

/// Validation helper for "type one" emoji inputs (goal icon picker, etc).
/// Filters arbitrary text down to the first emoji grapheme. Letters,
/// digits and punctuation are dropped so users can't save a goal called
/// "Tokyo trip" with the icon "T".
enum EmojiInput {
    /// Returns at most one emoji grapheme from the input. If the input
    /// contains no emoji, returns the empty string.
    static func sanitize(_ raw: String) -> String {
        for char in raw {
            if isEmoji(char) {
                return String(char)
            }
        }
        return ""
    }

    /// True when the grapheme reads as an emoji at default presentation.
    /// We require `isEmojiPresentation` so that ambiguous characters that
    /// merely qualify as emoji (digits, `#`, `*`) are excluded unless
    /// they're paired with a variation selector that forces emoji style.
    static func isEmoji(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        // Variation-selector-16 (U+FE0F) forces emoji style on otherwise
        // ambiguous scalars - so a "1️⃣" keycap counts even though "1" alone
        // does not.
        if scalars.contains(where: { $0.value == 0xFE0F }),
           scalars.contains(where: { $0.properties.isEmoji }) {
            return true
        }
        return scalars.contains { $0.properties.isEmojiPresentation }
    }
}
