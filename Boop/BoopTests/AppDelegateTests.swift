//
//  AppDelegateTests.swift
//  BoopTests
//

import Cocoa
import XCTest

class AppDelegateTests: XCTestCase {

    func testMenuBarIconPreferencePersistsAndApplies() {
        let suite = "BoopMenuBarTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let delegate = AppDelegate()
        delegate.preferences = defaults

        XCTAssertTrue(delegate.menuBarIconEnabled)
        delegate.setMenuBarIconEnabled(false)
        XCTAssertFalse(delegate.menuBarIconEnabled)
        XCTAssertFalse(defaults.bool(forKey: AppDelegate.menuBarIconPreferenceKey))
        XCTAssertNil(delegate.statusItem)
        XCTAssertTrue(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))

        delegate.setMenuBarIconEnabled(true)
        XCTAssertTrue(delegate.menuBarIconEnabled)
        XCTAssertNotNil(delegate.statusItem)
        delegate.setMenuBarIconEnabled(false)
    }

    func testMenuBarImageIsTransparentTemplate() {
        let iconURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Boop/Assets.xcassets/AppIcon.appiconset/icon_128x128.png")
        let source = try! XCTUnwrap(NSImage(contentsOf: iconURL))
        let image = AppDelegate.menuBarImage(from: source)

        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        let bitmap = try! XCTUnwrap(image.representations.first as? NSBitmapImageRep)
        let center = try! XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2,
                                                    y: bitmap.pixelsHigh / 2))
        XCTAssertLessThan(center.alphaComponent, 0.1)
    }

    func testStaysResidentAfterLastWindowClosed() {
        let suite = "BoopWindowTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let delegate = AppDelegate()
        delegate.preferences = defaults
        XCTAssertFalse(
            delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        )
    }

    func testReopenRestoresHiddenWindow() {
        let delegate = AppDelegate()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        delegate.window = window
        window.orderOut(nil)
        XCTAssertFalse(window.isVisible)

        XCTAssertTrue(
            delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        )
        XCTAssertTrue(window.isVisible)
    }

    func testReopenWithVisibleWindowsDoesNothingHarmful() {
        XCTAssertTrue(
            AppDelegate().applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true)
        )
    }
}
