//
//  AppDelegate.swift
//  Boop
//
//  Created by Ivan on 1/26/19.
//  Copyright © 2019 OKatBest. All rights reserved.
//

import Cocoa
import SavannaKit
import os.log

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var openPickerMenuItem: NSMenuItem!
    @IBOutlet weak var closePickerMenuItem: NSMenuItem!
    
    @IBOutlet weak var popoverViewController: PopoverViewController!
    @IBOutlet weak var scriptManager: ScriptManager!
    @IBOutlet weak var editor: BoopEditorView!

    static let menuBarIconPreferenceKey = "boopShowMenuBarIcon"
    var preferences = UserDefaults.standard
    private(set) var statusItem: NSStatusItem?

    var menuBarIconEnabled: Bool {
        preferences.object(forKey: Self.menuBarIconPreferenceKey) as? Bool ?? true
    }

    // Frame auto save name for app window frame restoration.
    private static let appWindowName = "boop.app.window"
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        os_log("willFinishLaunching", log: BoopLog.app, type: .info)
        ThemeSettingsViewController.applyTheme()

        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.servicesProvider = self

        // Restore app window frame.
        window.setFrameUsingName(AppDelegate.appWindowName)
        os_log("restored window frame %{public}@", log: BoopLog.app, type: .info,
               NSStringFromRect(window.frame))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log("didFinishLaunching", log: BoopLog.app, type: .info)
        updateMenuBarIcon()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Memorize app window frame for restoration.
        window.saveFrame(usingName: AppDelegate.appWindowName)
    }

    // MARK: - Menu bar icon

    /// Top status bar icon. Click toggles the main window.
    func setMenuBarIconEnabled(_ enabled: Bool) {
        preferences.set(enabled, forKey: Self.menuBarIconPreferenceKey)
        updateMenuBarIcon()
    }

    private func updateMenuBarIcon() {
        guard menuBarIconEnabled else {
            if let statusItem = statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
            return
        }
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else {
            os_log("menu bar button unavailable, status item skipped",
                   log: BoopLog.app, type: .error)
            return
        }

        button.image = Self.menuBarImage(from: NSApp.applicationIconImage)
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel("Boop")
        button.action = #selector(toggleWindow(_:))
        button.target = self
        os_log("menu bar icon installed", log: BoopLog.app, type: .info)
    }

    static func menuBarImage(from appIcon: NSImage) -> NSImage {
        let pixels = 36
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        appIcon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
                     from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        for y in 0..<pixels {
            for x in 0..<pixels {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                let brightness = max(color.redComponent, color.greenComponent,
                                     color.blueComponent)
                let stroke = min(1, max(0, (brightness - 0.35) / 0.5))
                bitmap.setColor(NSColor(deviceRed: 0, green: 0, blue: 0,
                                        alpha: color.alphaComponent * stroke),
                                atX: x, y: y)
            }
        }

        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.addRepresentation(bitmap)
        image.isTemplate = true
        return image
    }

    @objc func toggleWindow(_ sender: Any?) {
        os_log("toggleWindow visible=%ld active=%ld", log: BoopLog.app, type: .info,
               window.isVisible ? 1 : 0, NSApp.isActive ? 1 : 0)
        if window.isVisible && NSApp.isActive {
            window.orderOut(sender)
        } else {
            window.makeKeyAndOrderFront(sender)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let shouldQuit = !menuBarIconEnabled
        os_log("last window closed, quit=%ld", log: BoopLog.app, type: .info,
               shouldQuit ? 1 : 0)
        return shouldQuit
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        os_log("reopen hasVisibleWindows=%ld", log: BoopLog.app, type: .info, flag ? 1 : 0)
        if !flag {
            window?.makeKeyAndOrderFront(sender)
        }
        return true
    }

    @IBAction func showPreferencesWindow(_ sender: NSMenuItem) {
        let controller = NSStoryboard.init(name: "Preferences", bundle: nil).instantiateInitialController() as? NSWindowController
        
        controller?.showWindow(sender)
        
    }
    
    // Menu Stuff
    
    @IBAction func openPickerMenu(_ sender: NSMenuItem) {
        popoverViewController.show()
    }
    
    @IBAction func closePickerMenu(_ sender: Any) {
        popoverViewController.hide()
    }
    
    @IBAction func executeLastScript(_ sender: Any) {
        popoverViewController.runScriptAgain()
    }
    
    @IBAction func reloadScripts(_ sender: Any) {
        scriptManager.reloadScripts()
    }
    
    func setPopover(isOpen: Bool) {
        closePickerMenuItem.isHidden = !isOpen
        openPickerMenuItem.isHidden = isOpen
    }

    @objc func textServiceHandler(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        if let string = pboard.string(forType: NSPasteboard.PasteboardType.string) {
            os_log("service received %ld characters", log: BoopLog.app, type: .info,
                   string.count)
            editor.contentTextView.string = string
            NotificationCenter.default.post(name: .boopContentChanged, object: editor)
        } else {
            os_log("service received no string", log: BoopLog.app, type: .error)
        }
    }

}
