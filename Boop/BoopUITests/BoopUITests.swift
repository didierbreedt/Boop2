//
//  BoopUITests.swift
//  BoopUITests
//
//  End-to-end proof that keystrokes land in the editor textarea,
//  not in the tab bar. Runs the real app via the UI automation
//  channel, so no input-monitoring permission is needed.
//

import XCTest

class BoopUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launches the app with its tab storage pointed at a throwaway file,
    /// so tests always start with one fresh empty tab and never touch
    /// (or inherit) the user's real tabs.
    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["BOOP2_TABS_FILE"] = FileManager.default.temporaryDirectory
            .appendingPathComponent("BoopUITabs-\(UUID().uuidString).json").path
        app.launch()
        // Another copy of the app may be running (e.g. the installed one),
        // so force this instance frontmost before synthesizing keystrokes.
        app.activate()
        return app
    }

    /// Types into the editor, retrying the first keystroke until it lands.
    /// The first keystroke after a focus change can be swallowed while the
    /// window finishes activating (especially with another copy of the app
    /// running), so wait for it explicitly instead of losing characters.
    private func typeTextReliably(_ text: String, into editor: XCUIElement) {
        editor.click()
        let first = String(text.prefix(1))
        var landed = false
        for _ in 0..<5 {
            editor.typeText(first)
            let seen = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value CONTAINS %@", first),
                object: editor
            )
            if XCTWaiter.wait(for: [seen], timeout: 5) == .completed {
                landed = true
                break
            }
            editor.click()
        }
        XCTAssertTrue(landed, "first keystroke never reached the editor")
        editor.typeText(String(text.dropFirst()))
    }

    /// The reported bug: on a fresh launch, typing immediately (without
    /// clicking anywhere) must land in the editor, not the tab bar.
    func testTypingWithoutClickingFirst() {
        let app = launchFreshApp()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15), "main window never appeared")

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "editor text view not exposed")

        // Deliberately no clicks: this is the exact reported flow.
        // Wait for the first keystroke to land before sending the rest,
        // since it can be swallowed while the window finishes activating.
        app.typeText("n")
        let focused = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS 'n'"),
            object: editor
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [focused], timeout: 10),
            .completed,
            "first keystroke never reached the editor (focus race)"
        )
        app.typeText("oclick")

        let value = (editor.value as? String) ?? ""
        XCTAssertTrue(
            value.contains("noclick"),
            "fresh-launch typing missed the editor, got: \(value)"
        )
    }

    /// The exact reported flow: click + for a new tab, then type
    /// without clicking the editor.
    func testCreateTabThenType() {
        let app = launchFreshApp()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15), "main window never appeared")

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "editor text view not exposed")

        app.buttons["tab.add"].click()
        let tab = app.buttons["tab.select.1"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(editor.frame.minY, tab.frame.maxY,
                                    "editor text is covered by the tab bar")
        // The add button must return focus without an editor click.
        app.typeText("plustab")

        let value = (editor.value as? String) ?? ""
        XCTAssertTrue(
            value.contains("plustab"),
            "post-+ typing missed the editor, got: \(value)"
        )

        let typedShot = XCTAttachment(screenshot: app.screenshot())
        typedShot.lifetime = .keepAlways
        add(typedShot)

        // Select-all must render the blue selection highlight.
        app.typeKey("a", modifierFlags: [.command])
        let selectedShot = XCTAttachment(screenshot: app.screenshot())
        selectedShot.lifetime = .keepAlways
        add(selectedShot)
    }

    func testTypingLandsInEditor() {
        let app = launchFreshApp()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15), "main window never appeared")

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "editor text view not exposed")
        typeTextReliably("hello ui", into: editor)

        let value = (editor.value as? String) ?? ""
        XCTAssertTrue(
            value.contains("hello ui"),
            "typed text missing from editor, got: \(value)"
        )

        let tabButton = app.buttons["tab.select.0"]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5), "no tab button exposed")
        let titleExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS 'hello ui'"),
            object: tabButton
        )
        let titleResult = XCTWaiter.wait(for: [titleExpectation], timeout: 10)
        XCTAssertEqual(titleResult, .completed, "tab title did not follow typed text")

        let stats = app.staticTexts.containing(
            NSPredicate(format: "value CONTAINS[c] 'words'")
        ).firstMatch
        XCTAssertTrue(stats.waitForExistence(timeout: 5), "stats bar missing")
        XCTAssertTrue(
            (stats.value as? String ?? "").contains("2 words"),
            "stats wrong, got: \(stats.value as? String ?? "")"
        )
        XCTAssertTrue(
            (stats.value as? String ?? "").contains("· v"),
            "status bar missing version, got: \(stats.value as? String ?? "")"
        )
    }

    func testTabsRestoreAfterRestart() {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("BoopUITabs-\(UUID().uuidString).json").path
        let app = XCUIApplication()
        app.launchEnvironment["BOOP2_TABS_FILE"] = file
        app.launch()
        app.activate()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.click()
        editor.typeText("first tab")
        app.buttons["tab.add"].click()
        editor.typeText("second tab")
        app.typeKey("q", modifierFlags: [.command])
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))

        app.launch()
        app.activate()
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        XCTAssertEqual(editor.value as? String, "second tab")
        XCTAssertTrue(app.buttons["tab.select.0"].exists)
        XCTAssertTrue(app.buttons["tab.select.1"].exists)
        app.buttons["tab.select.0"].click()
        XCTAssertTrue((editor.value as? String ?? "").contains("first tab"))
    }

    func testBoopScriptStillEditsNativeEditor() {
        let app = launchFreshApp()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.click()
        editor.typeText(" hello ")

        app.typeKey("b", modifierFlags: [.command])
        let search = app.textFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.typeText("Trim")
        XCTAssertTrue(app.staticTexts["Trim"].waitForExistence(timeout: 5),
                      "Trim script did not appear in the picker: \(app.debugDescription)")
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])

        let trimmed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == 'hello'"), object: editor
        )
        XCTAssertEqual(XCTWaiter.wait(for: [trimmed], timeout: 5), .completed,
                       "script result: \(editor.value as? String ?? "nil")")
    }

    func testKeyboardTabShortcuts() {
        let app = launchFreshApp()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))

        app.typeKey("t", modifierFlags: [.command])
        XCTAssertTrue(app.buttons["tab.select.1"].waitForExistence(timeout: 5))
        editor.typeText("shortcut tab")

        app.typeKey("1", modifierFlags: [.command])
        XCTAssertEqual(editor.value as? String, "")
        app.typeKey("2", modifierFlags: [.command])
        XCTAssertEqual(editor.value as? String, "shortcut tab")
    }
}
