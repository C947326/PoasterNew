//
//  CharacterCountView.swift
//  Poaster
//

import SwiftUI

/// Displays the character count with visual feedback
struct CharacterCountView: View {
    let text: String
    var limit: Int = Constants.CharacterLimits.standard

    /// Computed character count
    private var characterCount: Int {
        CharacterCounter.count(text)
    }

    /// Remaining characters
    private var remaining: Int {
        limit - characterCount
    }

    /// Percentage of limit used
    private var percentage: Double {
        CharacterCounter.percentageUsed(text, limit: limit)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Circular progress indicator
            CircularProgressView(progress: min(percentage, 1.0), isOverLimit: remaining < 0)
                .frame(width: 24, height: 24)

            // Character count text
            Text("\(remaining)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(textColor)
        }
    }

    /// Color based on remaining characters
    private var textColor: Color {
        if remaining < 0 {
            return .red
        } else if remaining <= 20 {
            return .orange
        } else {
            return .secondary
        }
    }
}

/// A circular progress indicator similar to X's character counter
struct CircularProgressView: View {
    let progress: Double
    let isOverLimit: Bool

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 2)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(strokeColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: progress)
        }
    }

    private var strokeColor: Color {
        if isOverLimit {
            return .red
        } else if progress > 0.9 {
            return .orange
        } else {
            return .blue
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CharacterCountView(text: "Hello, World!")
        CharacterCountView(text: String(repeating: "a", count: 270))
        CharacterCountView(text: String(repeating: "a", count: 285))
    }
    .padding()
}
