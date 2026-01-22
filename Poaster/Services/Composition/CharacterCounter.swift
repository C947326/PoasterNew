//
//  CharacterCounter.swift
//  Poaster
//

import Foundation

/// Pure functions for X-aware character counting
///
/// X uses weighted character counting where:
/// - URLs count as 23 characters (t.co shortening)
/// - Emojis count as their visual length
/// - Most characters count as 1
enum CharacterCounter {

    // MARK: - URL Detection

    /// Regular expression pattern for detecting URLs
    private static let urlPattern = try! NSRegularExpression(
        pattern: #"https?://[^\s]+"#,
        options: .caseInsensitive
    )

    // MARK: - Public API

    /// Count the weighted characters in text using X's rules
    /// - Parameter text: The text to count
    /// - Returns: The weighted character count
    static func count(_ text: String) -> Int {
        var count = 0
        var textToCount = text

        // Find all URLs and replace them with placeholders for counting
        let range = NSRange(text.startIndex..., in: text)
        let matches = urlPattern.matches(in: text, options: [], range: range)

        // Process URLs in reverse order to maintain string indices
        for match in matches.reversed() {
            guard let swiftRange = Range(match.range, in: textToCount) else { continue }
            // Each URL counts as 23 characters
            count += Constants.CharacterLimits.urlLength
            // Remove the URL from the text we'll count later
            textToCount.replaceSubrange(swiftRange, with: "")
        }

        // Count remaining characters
        // Using extended grapheme clusters to properly count emojis
        count += textToCount.count

        return count
    }

    /// Calculate remaining characters for a given limit
    /// - Parameters:
    ///   - text: The text to count
    ///   - limit: The character limit (defaults to standard 280)
    /// - Returns: Number of characters remaining (negative if over)
    static func remaining(_ text: String, limit: Int = Constants.CharacterLimits.standard) -> Int {
        limit - count(text)
    }

    /// Check if text is within the character limit
    /// - Parameters:
    ///   - text: The text to check
    ///   - limit: The character limit (defaults to standard 280)
    /// - Returns: True if within limit
    static func isWithinLimit(_ text: String, limit: Int = Constants.CharacterLimits.standard) -> Bool {
        remaining(text, limit: limit) >= 0
    }

    /// Calculate the percentage of the limit used
    /// - Parameters:
    ///   - text: The text to count
    ///   - limit: The character limit (defaults to standard 280)
    /// - Returns: Percentage from 0.0 to 1.0+ (can exceed 1.0 if over limit)
    static func percentageUsed(_ text: String, limit: Int = Constants.CharacterLimits.standard) -> Double {
        Double(count(text)) / Double(limit)
    }
}
