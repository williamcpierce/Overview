/*
 Shortcut/ShortcutManager.swift
 Overview

 Created by William Pierce on 2/16/25.
*/

import KeyboardShortcuts
import SwiftUI

@MainActor
final class ShortcutManager: ObservableObject {
    // Dependencies
    private var sourceManager: SourceManager
    private let logger = AppLogger.shortcuts

    init(sourceManager: SourceManager) {
        self.sourceManager = sourceManager
        logger.debug("Initializing ShortcutManager")
        setupShortcuts()
    }

    private func setupShortcuts() {
        // Register callback for window focusing shortcut
        KeyboardShortcuts.onKeyDown(for: .focusSelectedWindow) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.activateSourceWindow()
            }
        }
    }

    private func activateSourceWindow() {
        // Get window title from storage and focus it
        guard let windowTitle = ShortcutStorage.shared.windowTitle else {
            logger.warning("No window title stored for keyboard shortcut")
            return
        }

        let activated = sourceManager.focusSource(withTitle: windowTitle)

        if activated {
            logger.info("Window focused via shortcut: '\(windowTitle)'")
        } else {
            logger.warning("Failed to focus window: '\(windowTitle)'")
        }
    }
}
