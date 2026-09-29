//
//  TextStats.swift
//  Boop
//
//  Pure word-processing statistics for the status bar.
//  Kept free of AppKit so the counting logic stays unit testable.
//

import Foundation

struct TextStats: Equatable {
    var words: Int
    var characters: Int
    var lines: Int

    static let empty = TextStats(words: 0, characters: 0, lines: 0)

    /// Computes stats for the given text.
    /// - Words: runs of non-whitespace characters.
    /// - Characters: extended grapheme clusters (`String.count`).
    /// - Lines: newline-separated rows; empty text reports 0 lines.
    static func compute(for text: String) -> TextStats {
        let characters = text.count

        var words = 0
        var inWord = false
        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                inWord = false
            } else if !inWord {
                inWord = true
                words += 1
            }
        }

        let lines: Int
        if text.isEmpty {
            lines = 0
        } else {
            lines = text.components(separatedBy: "\n").count
        }

        return TextStats(words: words, characters: characters, lines: lines)
    }

    /// One-line status bar summary.
    /// Shows selection stats first when a non-empty selection exists.
    static func describe(total: TextStats, selection: TextStats?) -> String {
        let totalText = "\(total.words) words  \(total.characters) characters  \(total.lines) lines"
        guard let selection = selection, selection.characters > 0 else {
            return totalText
        }
        return "\(selection.words) words selected  (\(totalText))"
    }
}
