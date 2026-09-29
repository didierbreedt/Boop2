//
//  BoopTests.swift
//  BoopTests
//
//  Created by Ivan on 3/21/20.
//  Copyright © 2020 OKatBest. All rights reserved.
//

import XCTest

class BoopTests: XCTestCase {

    func testEditorShowsLineNumberRuler() {
        let editor = BoopEditorView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))

        XCTAssertTrue(editor.scrollView.hasVerticalRuler)
        XCTAssertTrue(editor.scrollView.rulersVisible)
        XCTAssertNotNil(editor.scrollView.verticalRulerView)

        let ruler = editor.scrollView.verticalRulerView as? LineNumberRulerView
        XCTAssertEqual(ruler?.lineNumber(at: 0, in: "one\ntwo\r\nthree"), 1)
        XCTAssertEqual(ruler?.lineNumber(at: 4, in: "one\ntwo\r\nthree"), 2)
        XCTAssertEqual(ruler?.lineNumber(at: 9, in: "one\ntwo\r\nthree"), 3)
    }

    func testTabItemHasItsOwnCloseButton() {
        let tab = TabItemView(index: 0, title: "Notes", selected: true)

        XCTAssertEqual(tab.selectButton.title, "1  Notes")
        XCTAssertEqual(tab.closeButton.title, "×")
        XCTAssertTrue(tab.closeButton.isEnabled)
    }

    func testTabItemShowsShortcutNumber() {
        let first = TabItemView(index: 0, title: "Notes", selected: true)
        let third = TabItemView(index: 2, title: "Draft", selected: false)

        XCTAssertEqual(first.selectButton.attributedTitle.string, "1  Notes")
        XCTAssertEqual(third.selectButton.attributedTitle.string, "3  Draft")
    }

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
