//
//  TextStatsTests.swift
//  BoopTests
//

import XCTest

class TextStatsTests: XCTestCase {

    func testEmpty() {
        XCTAssertEqual(TextStats.compute(for: ""), .empty)
    }

    func testWordsCharactersLines() {
        XCTAssertEqual(
            TextStats.compute(for: "hello world\nfoo"),
            TextStats(words: 3, characters: 15, lines: 2)
        )
    }

    func testWhitespaceOnlyHasNoWords() {
        let stats = TextStats.compute(for: "   ")
        XCTAssertEqual(stats.words, 0)
        XCTAssertEqual(stats.characters, 3)
    }

    func testDescribeWithoutSelection() {
        let text = TextStats.describe(
            total: TextStats(words: 10, characters: 50, lines: 2),
            selection: nil
        )
        XCTAssertEqual(text, "10 words  50 characters  2 lines")
    }

    func testDescribeWithSelection() {
        let text = TextStats.describe(
            total: TextStats(words: 10, characters: 50, lines: 2),
            selection: TextStats(words: 2, characters: 9, lines: 1)
        )
        XCTAssertTrue(text.hasPrefix("2 words selected"))
    }
}
