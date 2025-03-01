/*
 Shortcut/ShortcutStorage.swift
 Overview

 Created by William Pierce on 2/16/25.
*/

import Defaults
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

    // Shortcut Settings
    private var storedShortcuts = Defaults[.storedShortcuts]

    init() {
        self.shortcuts = ShortcutStorage.loadShortcuts()
        logger.debug("Keyboard shortcut storage initialized")
    }
    
    // MARK: - Public Methods

    func addShortcut(windowTitles: [String]) {
        let shortcutName = KeyboardShortcuts.Name("windowShortcut_\(UUID().uuidString)")
        let shortcut = ShortcutItem(windowTitles: windowTitles, shortcutName: shortcutName)
        shortcuts.append(shortcut)
        logger.info(
            "Added new keyboard shortcut for windows: '\(windowTitles.joined(separator: ", "))'")
    }

    func updateShortcutTitles(_ shortcut: ShortcutItem, titles: [String]) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            var updatedShortcut = shortcuts[index]
            updatedShortcut.windowTitles = titles
            shortcuts[index] = updatedShortcut
            logger.info(
                "Updated window titles for shortcut: '\(titles.joined(separator: ", "))'")
        } else {
            logger.warning("Cannot update titles: shortcut not found")
        }
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
        let shortcutsToReset = shortcuts
        shortcuts.removeAll()
        shortcutsToReset.forEach { shortcut in
            KeyboardShortcuts.reset(shortcut.shortcutName)
        }
        storedShortcuts = nil
        logger.info("Keyboard shortcut settings reset completed")
    }
    
    // MARK: - Private Methods

    private func saveShortcuts() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            storedShortcuts = encoded
        }
    }

    private static func loadShortcuts() -> [ShortcutItem] {
        guard let data = Defaults[.storedShortcuts],
            let shortcuts = try? JSONDecoder().decode([ShortcutItem].self, from: data)
        else {
            return []
        }
        return shortcuts
    }
}
