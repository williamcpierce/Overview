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
    @Published var windowTitle: String? {
        didSet {
            UserDefaults.standard.set(
                windowTitle, forKey: ShortcutSettingsKeys.storedWindowTitle)
        }
    }

    // Singleton
    static let shared = ShortcutStorage()

    private init() {
        // Load saved window title
        self.windowTitle = UserDefaults.standard.string(
            forKey: ShortcutSettingsKeys.storedWindowTitle)
        logger.debug("Keyboard shortcut storage initialized")
    }

    func resetToDefaults() {
        logger.debug("Resetting keyboard shortcut settings")
        windowTitle = nil
        KeyboardShortcuts.reset(.focusSelectedWindow)
        logger.info("Keyboard shortcut settings reset completed")
    }
}
