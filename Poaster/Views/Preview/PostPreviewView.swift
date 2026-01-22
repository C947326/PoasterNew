//
//  PostPreviewView.swift
//  Poaster
//

import SwiftUI

/// Text view with X-style attributed text (URLs, @mentions, #hashtags)
struct AttributedPostText: View {
    let text: String

    var body: some View {
        Text(attributedString)
    }

    /// Parse text and create attributed string with links styled
    private var attributedString: AttributedString {
        var result = AttributedString(text)

        // Style URLs
        let urlPattern = try? NSRegularExpression(pattern: #"https?://[^\s]+"#, options: .caseInsensitive)
        if let matches = urlPattern?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let range = Range(match.range, in: text),
                   let attrRange = Range(range, in: result) {
                    result[attrRange].foregroundColor = .blue
                }
            }
        }

        // Style @mentions
        let mentionPattern = try? NSRegularExpression(pattern: #"@\w+"#, options: [])
        if let matches = mentionPattern?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let range = Range(match.range, in: text),
                   let attrRange = Range(range, in: result) {
                    result[attrRange].foregroundColor = .blue
                }
            }
        }

        // Style #hashtags
        let hashtagPattern = try? NSRegularExpression(pattern: #"#\w+"#, options: [])
        if let matches = hashtagPattern?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let range = Range(match.range, in: text),
                   let attrRange = Range(range, in: result) {
                    result[attrRange].foregroundColor = .blue
                }
            }
        }

        return result
    }
}

#Preview {
    AttributedPostText(text: "Hello @world! Check out https://example.com and #SwiftUI")
}
