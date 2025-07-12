/*
 Shortcut/ShortcutStorage.swift
 Overview

 Created by William Pierce on 2/16/25.
*/

import Defaults
import KeyboardShortcuts
import SwiftUI

@MainActor
final class ShortcutStorage: ObservableObject {
    // Dependencies
    private let logger = AppLogger.settings

    // Published State
    @Published var shortcuts: [Shortcut] {
        didSet {
            saveShortcuts()
        }
    }

    init() {
        self.shortcuts = ShortcutStorage.loadShortcuts()
        logger.debug("Keyboard shortcut initialized with \(shortcuts.count) shortcuts")
    }

    // MARK: - Public Methods

    func createShortcut(windowTitles: [String]) -> Shortcut? {
        let shortcutName = KeyboardShortcuts.Name("windowShortcut_\(UUID().uuidString)")

        let shortcut = Shortcut(windowTitles: windowTitles, shortcutName: shortcutName)
        shortcuts.append(shortcut)

        logger.info(
            "Added new keyboard shortcut for windows: '\(windowTitles.joined(separator: ", "))'")
        return shortcut
    }

    func updateShortcut(id: UUID, windowTitles: [String]) {
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else {
            logger.warning("Attempted to update non-existent shortcut: \(id)")
            return
        }

        var shortcut = shortcuts[index]
        shortcut.windowTitles = windowTitles
        shortcuts[index] = shortcut
        logger.info(
            "Updated window titles for shortcut: '\(windowTitles.joined(separator: ", "))'")
    }

    func updateShortcut(id: UUID, isEnabled: Bool) {
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else {
            logger.warning("Attempted to update non-existent shortcut: \(id)")
            return
        }

        var shortcut = shortcuts[index]
        shortcut.isEnabled = isEnabled
        shortcuts[index] = shortcut
        logger.info(
            "\(isEnabled ? "Enabled" : "Disabled") shortcut for windows: '\(shortcut.windowTitles.joined(separator: ", "))'"
        )
    }

    func deleteShortcut(id: UUID) {
        guard let shortcut = shortcuts.first(where: { $0.id == id }) else {
            logger.warning("Attempted to delete non-existent shortcut: \(id)")
            return
        }
        let windowTitles = shortcut.windowTitles
        KeyboardShortcuts.reset(shortcut.shortcutName)
        shortcuts.removeAll(where: { $0.id == id })

        logger.info(
            "Removed shortcut for windows: '\(windowTitles.joined(separator: ", "))'"
        )
    }

    func resetToDefaults() {
        logger.debug("Resetting shortcut storage")
        let shortcutsToReset = shortcuts
        shortcutsToReset.forEach { shortcut in
            KeyboardShortcuts.reset(shortcut.shortcutName)
        }
        shortcuts = []
        Defaults[.storedShortcuts] = nil
        logger.info("Shortcut storage reset completed")
    }

    // MARK: - Private Methods

    private func saveShortcuts() {
        do {
            let encodedShortcuts = try JSONEncoder().encode(shortcuts)
            Defaults[.storedShortcuts] = encodedShortcuts
            logger.debug("Saved \(shortcuts.count) shortcuts to user defaults")
        } catch {
            logger.logError(error, context: "Failed to encode shortcuts")
        }
    }

    private static func loadShortcuts() -> [Shortcut] {
        guard let data = Defaults[.storedShortcuts],
            let shortcuts = try? JSONDecoder().decode([Shortcut].self, from: data)
        else {
            return []
        }
        return shortcuts
    }
}
