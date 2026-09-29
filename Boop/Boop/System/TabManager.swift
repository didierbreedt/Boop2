//
//  TabManager.swift
//  Boop
//
//  In-app tabs backed by a JSON file in Application Support,
//  so open tabs survive restarts.
//

import Foundation
import os.log

struct TabItem: Codable, Equatable {
    var id: UUID
    var content: String

    init(id: UUID = UUID(), content: String = "") {
        self.id = id
        self.content = content
    }
}

private struct PersistedTabs: Codable {
    var tabs: [TabItem]
    var selectedID: UUID?
}

class TabManager {

    private static let saveQueue = DispatchQueue(label: "Boop.tabSave")

    private(set) var tabs: [TabItem] = [TabItem()]
    private(set) var selectedID: UUID?

    var selectedIndex: Int {
        guard let selectedID = selectedID else { return 0 }
        return tabs.firstIndex(where: { $0.id == selectedID }) ?? 0
    }

    static func storageURL() -> URL {
        // UI tests point this at a throwaway file so they never touch
        // (or inherit) the user's real tabs.
        if let override = ProcessInfo.processInfo.environment["BOOP2_TABS_FILE"],
           !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Boop", isDirectory: true)
            .appendingPathComponent("Tabs.json", isDirectory: false)
    }

    static func tabFileURL(for id: UUID) -> URL {
        storageURL().deletingLastPathComponent()
            .appendingPathComponent("Tabs", isDirectory: true)
            .appendingPathComponent(id.uuidString + ".txt")
    }

    /// Short display title derived from content.
    static func title(for content: String, fallback: String) -> String {
        let firstLine = content
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(24))
    }

    func load() {
        let url = TabManager.storageURL()
        guard
            let data = try? Data(contentsOf: url),
            let persisted = try? JSONDecoder().decode(PersistedTabs.self, from: data),
            !persisted.tabs.isEmpty
        else {
            os_log("no saved tabs at %{public}@, starting fresh",
                   log: BoopLog.tabs, type: .info, url.path)
            tabs = [TabItem()]
            selectedID = tabs[0].id
            return
        }
        os_log("loaded %ld tabs from %{public}@", log: BoopLog.tabs, type: .info,
               persisted.tabs.count, url.path)
        tabs = persisted.tabs.map { tab in
            var restored = tab
            if let text = try? String(contentsOf: Self.tabFileURL(for: tab.id),
                                      encoding: .utf8) {
                restored.content = text
            }
            return restored
        }
        if let selectedID = persisted.selectedID,
           tabs.contains(where: { $0.id == selectedID }) {
            self.selectedID = selectedID
        } else {
            self.selectedID = tabs[0].id
        }
    }

    func save() {
        let snapshot = PersistedTabs(tabs: tabs, selectedID: selectedID)
        let url = Self.storageURL()
        Self.saveQueue.sync {
            Self.persist(snapshot, to: url)
        }
    }

    func saveAsync() {
        let snapshot = PersistedTabs(tabs: tabs, selectedID: selectedID)
        let url = Self.storageURL()
        Self.saveQueue.async {
            Self.persist(snapshot, to: url)
        }
    }

    private static func persist(_ snapshot: PersistedTabs, to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent().appendingPathComponent("Tabs"),
                withIntermediateDirectories: true
            )
            for tab in snapshot.tabs {
                let file = url.deletingLastPathComponent()
                    .appendingPathComponent("Tabs", isDirectory: true)
                    .appendingPathComponent(tab.id.uuidString + ".txt")
                try tab.content.write(to: file,
                                      atomically: true, encoding: .utf8)
            }
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
            os_log("saved %ld tabs to %{public}@", log: BoopLog.tabs, type: .info,
                   snapshot.tabs.count, url.path)
        } catch {
            os_log("unable to save tabs: %{public}@", log: BoopLog.tabs, type: .error,
                   error.localizedDescription)
        }
    }

    func updateContent(at index: Int, text: String) {
        guard tabs.indices.contains(index) else { return }
        tabs[index].content = text
    }

    func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else {
            os_log("selectTab out of range: %ld of %ld", log: BoopLog.tabs, type: .error,
                   index, tabs.count)
            return
        }
        selectedID = tabs[index].id
        os_log("selected tab %ld", log: BoopLog.tabs, type: .debug, index)
    }

    func addTab() {
        let tab = TabItem()
        tabs.append(tab)
        selectedID = tab.id
        os_log("added tab, now %ld", log: BoopLog.tabs, type: .info, tabs.count)
    }

    /// Closes a tab. The last tab stays open to prevent accidental data loss.
    /// Returns the index that should become selected.
    @discardableResult
    func closeTab(at index: Int) -> Int {
        guard tabs.indices.contains(index) else { return selectedIndex }
        if tabs.count == 1 {
            return 0
        }
        let closingSelectedTab = tabs[index].id == selectedID
        tabs.remove(at: index)
        if closingSelectedTab {
            selectedID = tabs[min(index, tabs.count - 1)].id
        }
        return selectedIndex
    }
}
