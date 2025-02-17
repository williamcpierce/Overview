/*
 Shortcut/ShortcutStorage.swift
 Overview

 Created by William Pierce on 2/16/25.
*/

import Foundation
import KeyboardShortcuts
import SwiftUI

@MainActor
final class ShortcutStorage: ObservableObject {
    // Dependencies
    private let logger = AppLogger.settings

    // Published State
    @Published var shortcuts: [ShortcutItem] {
        didSet {
            saveShortcuts()
        }
    }

    // Singleton
    static let shared = ShortcutStorage()

    private init() {
        self.shortcuts = ShortcutStorage.loadShortcuts()
        logger.debug("Keyboard shortcut storage initialized")
    }

    func addShortcut(windowTitles: [String]) {
        let shortcutName = KeyboardShortcuts.Name("windowShortcut_\(UUID().uuidString)")
        let shortcut = ShortcutItem(windowTitles: windowTitles, shortcutName: shortcutName)
        shortcuts.append(shortcut)
        logger.info(
            "Added new keyboard shortcut for windows: '\(windowTitles.joined(separator: ", "))'")
    }

    func removeShortcut(_ shortcut: ShortcutItem) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            KeyboardShortcuts.reset(shortcut.shortcutName)
            shortcuts.remove(at: index)
            logger.info(
                "Removed keyboard shortcut for windows: '\(shortcut.windowTitles.joined(separator: ", "))'"
            )
        }
    }

    func resetToDefaults() {
        logger.debug("Resetting keyboard shortcut settings")
        shortcuts.forEach { shortcut in
            KeyboardShortcuts.reset(shortcut.shortcutName)
        }
        shortcuts.removeAll()
        logger.info("Keyboard shortcut settings reset completed")
    }

    private func saveShortcuts() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: ShortcutSettingsKeys.storedShortcuts)
        }
    }

    private static func loadShortcuts() -> [ShortcutItem] {
        guard let data = UserDefaults.standard.data(forKey: ShortcutSettingsKeys.storedShortcuts),
            let shortcuts = try? JSONDecoder().decode([ShortcutItem].self, from: data)
        else {
            return []
        }
        return shortcuts
    }
}
