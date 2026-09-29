//
//  PreferencesTabViewController.swift
//  Boop
//
//  Created by Ivan on 11/2/19.
//  Copyright © 2019 OKatBest. All rights reserved.
//

import Cocoa

class PreferencesTabViewController: NSTabViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let general = GeneralSettingsViewController()
        let item = NSTabViewItem(viewController: general)
        item.label = "General"
        if #available(macOS 11.0, *) {
            item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")
        } else {
            item.image = NSImage(named: NSImage.Name("NSPreferencesGeneral"))
        }
        insertTabViewItem(item, at: 0)
        selectedTabViewItemIndex = 0
    }
}

final class GeneralSettingsViewController: NSViewController {
    private let menuBarCheckBox = NSButton(
        checkboxWithTitle: "Show Boop icon in the menu bar",
        target: nil,
        action: nil
    )

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 410, height: 100))
        menuBarCheckBox.target = self
        menuBarCheckBox.action = #selector(menuBarIconChanged(_:))
        menuBarCheckBox.identifier = NSUserInterfaceItemIdentifier("settings.menuBarIcon")
        menuBarCheckBox.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(menuBarCheckBox)

        let explanation = NSTextField(labelWithString:
            "When hidden, Boop quits after you close its last window.")
        explanation.textColor = .secondaryLabelColor
        explanation.font = NSFont.systemFont(ofSize: 11)
        explanation.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(explanation)

        NSLayoutConstraint.activate([
            menuBarCheckBox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 25),
            menuBarCheckBox.topAnchor.constraint(equalTo: container.topAnchor, constant: 22),
            explanation.leadingAnchor.constraint(equalTo: menuBarCheckBox.leadingAnchor, constant: 20),
            explanation.topAnchor.constraint(equalTo: menuBarCheckBox.bottomAnchor, constant: 8),
        ])
        view = container
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        let enabled = (NSApp.delegate as? AppDelegate)?.menuBarIconEnabled ?? true
        menuBarCheckBox.state = enabled ? .on : .off
        preferredContentSize = view.fittingSize
    }

    @objc private func menuBarIconChanged(_ sender: NSButton) {
        (NSApp.delegate as? AppDelegate)?.setMenuBarIconEnabled(sender.state == .on)
    }
}
