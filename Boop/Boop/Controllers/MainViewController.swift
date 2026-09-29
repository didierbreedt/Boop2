//
//  MainViewController.swift
//  Boop
//
//  Created by Ivan on 1/26/19.
//  Copyright © 2019 OKatBest. All rights reserved.
//

import Cocoa
import os.log

class MainViewController: NSViewController {

    @IBOutlet weak var editorView: BoopEditorView!
    @IBOutlet weak var updateBuddy: UpdateBuddy!
    @IBOutlet weak var checkUpdateMenuItem: NSMenuItem!

    private let tabManager = TabManager()
    private var tabStack: NSStackView!
    private var tabScrollView: NSScrollView!
    private var addButton: NSButton!
    private var tabItems = [TabItemView]()
    private var keyboardMenusInstalled = false
    private var statsLabel: NSTextField!
    private var saveWorkItem: DispatchWorkItem?
    private var presentationWorkItem: DispatchWorkItem?
    private var observers = [NSObjectProtocol]()

    private let tabBarHeight: CGFloat = 32
    private let statsBarHeight: CGFloat = 22

    override func viewDidLoad() {
        super.viewDidLoad()

        #if APPSTORE

        checkUpdateMenuItem.isHidden = true

        #endif

        guard editorView != nil else {
            os_log("editorView outlet missing, chrome disabled",
                   log: BoopLog.app, type: .fault)
            return
        }

        editorView.contentTextView.delegate = self

        tabManager.load()
        os_log("viewDidLoad with %ld tabs, selected %ld",
               log: BoopLog.app, type: .info, tabManager.tabs.count, tabManager.selectedIndex)
        installChrome()
        showTab(at: tabManager.selectedIndex)
        tabManager.saveAsync()

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.syncEditorToTab()
            self.tabManager.save()
        })
        observers.append(center.addObserver(
            forName: .boopContentChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshFromEditor()
        })
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installKeyboardMenus()
        focusEditor()
    }

    private func installKeyboardMenus() {
        guard !keyboardMenusInstalled,
              let fileMenu = NSApp.mainMenu?.item(withTitle: "File")?.submenu,
              let windowMenu = NSApp.mainMenu?.item(withTitle: "Window")?.submenu else {
            return
        }

        let newTab = NSMenuItem(title: "New Tab", action: #selector(newTabFromMenu(_:)),
                                keyEquivalent: "t")
        newTab.target = self
        fileMenu.insertItem(newTab, at: 0)

        windowMenu.addItem(.separator())
        for number in 1...9 {
            let item = NSMenuItem(title: "Select Tab \(number)",
                                  action: #selector(selectNumberedTab(_:)),
                                  keyEquivalent: String(number))
            item.target = self
            item.tag = number
            windowMenu.addItem(item)
        }
        keyboardMenusInstalled = true
    }

    @objc private func newTabFromMenu(_ sender: NSMenuItem) {
        addTab(sender)
    }

    @objc private func selectNumberedTab(_ sender: NSMenuItem) {
        let index = sender.tag - 1
        guard tabManager.tabs.indices.contains(index) else { return }
        tabSelected(at: index)
    }

    /// Keyboard focus belongs to the editor, never to the tab bar.
    private func focusEditor(_ source: String = #function) {
        view.window?.initialFirstResponder = editorView.contentTextView
        let accepted = view.window?.makeFirstResponder(editorView.contentTextView) ?? false
        let responder = view.window?.firstResponder.map { String(describing: type(of: $0)) }
        os_log("focus from %{public}@ windowNil=%ld accepted=%ld responder=%{public}@",
               log: BoopLog.app, type: .info,
               source, view.window == nil ? 1 : 0, accepted ? 1 : 0, responder ?? "nil")
    }

    // MARK: - Window chrome (tab bar + stats bar)

    /// The content view owns the editor and both bars.
    private func installChrome() {
        let container = view

        let tabBar = NSStackView()
        tabBar.orientation = .horizontal
        tabBar.spacing = 6
        tabBar.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        tabBar.translatesAutoresizingMaskIntoConstraints = false

        tabStack = NSStackView()
        tabStack.orientation = .horizontal
        tabStack.spacing = 4
        tabStack.alignment = .centerY
        tabScrollView = NSScrollView()
        tabScrollView.drawsBackground = false
        tabScrollView.borderType = .noBorder
        tabScrollView.hasHorizontalScroller = true
        tabScrollView.autohidesScrollers = true
        tabScrollView.documentView = tabStack
        tabScrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tabBar.addArrangedSubview(tabScrollView)

        addButton = NSButton(title: "+", target: self, action: #selector(addTab(_:)))
        addButton.bezelStyle = .inline
        addButton.setButtonType(.momentaryPushIn)
        addButton.toolTip = "New tab"
        addButton.setAccessibilityLabel("New tab")
        addButton.identifier = NSUserInterfaceItemIdentifier("tab.add")
        addButton.refusesFirstResponder = true
        tabStack.addArrangedSubview(addButton)

        let statsBar = NSView()
        statsBar.translatesAutoresizingMaskIntoConstraints = false

        statsLabel = NSTextField(labelWithString: "")
        statsLabel.font = NSFont.systemFont(ofSize: 11)
        statsLabel.textColor = NSColor.secondaryLabelColor
        statsLabel.alignment = .right
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statsBar.addSubview(statsLabel)

        container.addSubview(tabBar)
        container.addSubview(statsBar)

        // Release the editor's top/bottom pins so the bars fit.
        var released = 0
        for constraint in container.constraints {
            let first = constraint.firstItem as? NSObject
            let second = constraint.secondItem as? NSObject
            let pinsTop = first === editorView
                && constraint.firstAttribute == .top
                && second === container
                && constraint.secondAttribute == .top
            let pinsBottom = first === container
                && constraint.firstAttribute == .bottom
                && second === editorView
                && constraint.secondAttribute == .bottom
            if pinsTop || pinsBottom {
                constraint.isActive = false
                released += 1
            }
        }
        os_log("chrome installed, released %ld editor pins",
               log: BoopLog.app, type: .info, released)

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: container.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: tabBarHeight),
            tabScrollView.heightAnchor.constraint(equalToConstant: 24),
            tabScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

            statsBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            statsBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            statsBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            statsBar.heightAnchor.constraint(equalToConstant: statsBarHeight),

            statsLabel.trailingAnchor.constraint(equalTo: statsBar.trailingAnchor, constant: -8),
            statsLabel.centerYAnchor.constraint(equalTo: statsBar.centerYAnchor),

            editorView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            editorView.bottomAnchor.constraint(equalTo: statsBar.topAnchor),
        ])
    }

    // MARK: - Tabs

    private func tabSelected(at index: Int) {
        syncEditorToTab()
        showTab(at: index)
        tabManager.saveAsync()
    }

    @objc private func addTab(_ sender: Any) {
        syncEditorToTab()
        tabManager.addTab()
        showTab(at: tabManager.tabs.count - 1)
        tabManager.saveAsync()
    }

    private func closeTab(at index: Int) {
        syncEditorToTab()
        showTab(at: tabManager.closeTab(at: index))
        tabManager.saveAsync()
    }

    private func showTab(at index: Int) {
        guard tabManager.tabs.indices.contains(index) else {
            os_log("showTab out of range: %ld", log: BoopLog.app, type: .error, index)
            return
        }
        tabManager.selectTab(at: index)
        presentationWorkItem?.cancel()
        editorView.contentTextView.string = tabManager.tabs[index].content
        os_log("showing tab %ld (%ld characters)", log: BoopLog.stats, type: .info,
               index, tabManager.tabs[index].content.count)
        rebuildTabs()
        refreshStats()
        focusEditor()
    }

    private func rebuildTabs() {
        guard tabStack != nil else { return }
        for item in tabItems {
            tabStack.removeArrangedSubview(item)
            item.removeFromSuperview()
        }
        tabItems.removeAll()
        for (index, tab) in tabManager.tabs.enumerated() {
            let item = TabItemView(
                index: index,
                title: TabManager.title(for: tab.content, fallback: "Untitled \(index + 1)"),
                selected: index == tabManager.selectedIndex
            )
            item.onSelect = { [weak self] index in self?.tabSelected(at: index) }
            item.onClose = { [weak self] index in self?.closeTab(at: index) }
            item.closeButton.isEnabled = tabManager.tabs.count > 1
            tabStack.addArrangedSubview(item)
            tabItems.append(item)
        }
        tabStack.removeArrangedSubview(addButton)
        addButton.removeFromSuperview()
        tabStack.addArrangedSubview(addButton)
        tabStack.frame = NSRect(x: 0, y: 0,
                                width: CGFloat(tabItems.count) * 144 + 24,
                                height: 24)
        tabStack.needsLayout = true
    }

    private func syncEditorToTab() {
        tabManager.updateContent(at: tabManager.selectedIndex, text: editorView.text)
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.syncEditorToTab()
            self?.tabManager.saveAsync()
        }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    // MARK: - Stats

    private func refreshFromEditor() {
        schedulePresentation()
        scheduleSave()
    }

    private func schedulePresentation() {
        presentationWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let index = self.tabManager.selectedIndex
            if self.tabItems.indices.contains(index) {
                self.tabItems[index].title = TabManager.title(
                    for: self.editorView.text, fallback: "Untitled \(index + 1)"
                )
            }
            self.refreshStats()
        }
        presentationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }

    /// Version string shown at the end of the status bar, e.g. "v1.2 (34)".
    static func appVersion(bundle: Bundle = .main) -> String {
        let info = bundle.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "v\(short) (\(build))"
    }

    private func refreshStats() {
        guard statsLabel != nil else { return }
        let text = editorView.text
        let total = TextStats.compute(for: text)
        statsLabel.stringValue = TextStats.describe(
            total: total,
            selection: selectionStats(in: text)
        ) + " · " + Self.appVersion()
    }

    private func selectionStats(in text: String) -> TextStats? {
        guard let ranges = editorView.contentTextView.selectedRanges as? [NSRange] else {
            return nil
        }
        let selectedLength = ranges.reduce(0) { $0 + $1.length }
        guard selectedLength > 0 else { return nil }

        let nsText = text as NSString
        let selected = ranges
            .map { nsText.substring(with: $0) }
            .joined(separator: "\n")
        return TextStats.compute(for: selected)
    }

    @IBAction func openHelp(_ sender: Any) {
        open(url: "https://boop.okat.best/docs/")
    }


    @IBAction func openScripts(_ sender: Any) {
        open(url: "https://boop.okat.best/scripts/")
    }


    func open(url: String) {
        guard let url = URL(string: url) else {
            assertionFailure("Could not generate help URL.")
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func clear(_ sender: Any) {
        let textView = editorView.contentTextView
        let range = NSRange(location: 0, length: textView.textStorage?.length ?? textView.string.count)

        guard textView.shouldChangeText(in: range, replacementString: "") else {
            return
        }

        textView.textStorage?.beginEditing()
        textView.textStorage?.replaceCharacters(in: range, with: "")

        textView.textStorage?.endEditing()
        textView.didChangeText()
        refreshFromEditor()
    }

    @IBAction func revealTabFiles(_ sender: Any) {
        let folder = TabManager.storageURL().deletingLastPathComponent()
            .appendingPathComponent("Tabs", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder,
                                                    withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        } catch {
            os_log("unable to reveal tabs: %{public}@", log: BoopLog.tabs,
                   type: .error, error.localizedDescription)
        }
    }


    @IBAction func checkForUpdates(_ sender: Any) {
        updateBuddy.check()
    }
}

extension MainViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        refreshFromEditor()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        schedulePresentation()
    }
}

extension MainViewController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(selectNumberedTab(_:)) {
            return tabManager.tabs.indices.contains(menuItem.tag - 1)
        }
        return true
    }
}
