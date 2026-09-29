//
//  TabManagerTests.swift
//  BoopTests
//

import XCTest

class TabManagerTests: XCTestCase {

    func testClosingInactiveTabKeepsCurrentTabSelected() {
        let manager = TabManager()
        manager.updateContent(at: 0, text: "first")
        manager.addTab()
        manager.updateContent(at: 1, text: "second")
        manager.addTab()
        manager.updateContent(at: 2, text: "third")

        manager.closeTab(at: 0)

        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.tabs[manager.selectedIndex].content, "third")
    }

    func testTitleFallsBackForEmptyContent() {
        XCTAssertEqual(TabManager.title(for: "", fallback: "Untitled 1"), "Untitled 1")
        XCTAssertEqual(TabManager.title(for: "\n   \n", fallback: "Untitled 2"), "Untitled 2")
    }

    func testTitleUsesFirstNonEmptyLine() {
        XCTAssertEqual(
            TabManager.title(for: "\n  hello world  \nsecond", fallback: "U"),
            "hello world"
        )
    }

    func testAddSelectClose() {
        let manager = TabManager()
        XCTAssertEqual(manager.tabs.count, 1)

        manager.updateContent(at: 0, text: "first")
        manager.addTab()
        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.selectedIndex, 1)

        manager.updateContent(at: 1, text: "second")
        manager.selectTab(at: 0)
        XCTAssertEqual(manager.tabs[manager.selectedIndex].content, "first")

        let next = manager.closeTab(at: 0)
        XCTAssertEqual(next, 0)
        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertEqual(manager.tabs[0].content, "second")
    }

    func testClosingLastTabPreservesContent() {
        let manager = TabManager()
        manager.updateContent(at: 0, text: "something")

        _ = manager.closeTab(at: 0)

        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertEqual(manager.tabs[0].content, "something")
    }

    func testTabsSaveAsLocalTextFilesAndRestore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BoopTabs-\(UUID().uuidString)")
        let index = directory.appendingPathComponent("Tabs.json")
        setenv("BOOP2_TABS_FILE", index.path, 1)
        defer { unsetenv("BOOP2_TABS_FILE") }

        let manager = TabManager()
        manager.updateContent(at: 0, text: "local tab text")
        let id = manager.tabs[0].id
        manager.save()

        XCTAssertEqual(try String(contentsOf: TabManager.tabFileURL(for: id),
                                  encoding: .utf8), "local tab text")
        let restored = TabManager()
        restored.load()
        XCTAssertEqual(restored.tabs[0].content, "local tab text")
    }
}
