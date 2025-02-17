/*
 Shortcut/ShortcutManager.swift
 Overview

 Created by William Pierce on 2/16/25.
*/

import Combine
import KeyboardShortcuts
import SwiftUI

@MainActor
final class ShortcutManager: ObservableObject {
    // Dependencies
    private var sourceManager: SourceManager
    private let shortcutStorage = ShortcutStorage.shared
    private let logger = AppLogger.shortcuts

    // Private State
    private var cancellables = Set<AnyCancellable>()

    init(sourceManager: SourceManager) {
        self.sourceManager = sourceManager
        logger.debug("Initializing ShortcutManager")
        setupShortcuts()
    }

    private func setupShortcuts() {
        // Setup observers for all shortcuts
        shortcutStorage.shortcuts.forEach { shortcut in
            setupShortcutObserver(for: shortcut)
        }

        // Listen for changes to add/remove observers
        shortcutStorage.$shortcuts
            .dropFirst()
            .sink { [weak self] shortcuts in
                shortcuts.forEach { shortcut in
                    self?.setupShortcutObserver(for: shortcut)
                }
            }
            .store(in: &cancellables)
    }

    private func setupShortcutObserver(for shortcut: ShortcutItem) {
        KeyboardShortcuts.onKeyDown(for: shortcut.shortcutName) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.activateSourceWindow(withTitle: shortcut.windowTitle)
            }
        }
    }

    private func activateSourceWindow(withTitle title: String) {
        let activated = sourceManager.focusSource(withTitle: title)

        if activated {
            logger.info("Window focused via shortcut: '\(title)'")
        } else {
            logger.warning("Failed to focus window: '\(title)'")
        }
    }
}
