/*
 Shortcut/ShortcutManager.swift
 Overview

 Created by William Pierce on 2/16/25.

 Manages keyboard shortcut activation and window cycling functionality.
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

    // MARK: - Shortcut Setup

    private func setupShortcuts() {
        // Setup observers for all existing shortcuts
        shortcutStorage.shortcuts.forEach { shortcut in
            setupShortcutObserver(for: shortcut)
        }

        // Listen for changes to add/remove observers dynamically
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
                self.activateSourceWindow(for: shortcut)
            }
        }
    }

    // MARK: - Window Activation

    private func activateSourceWindow(for shortcut: ShortcutItem) {
        let titles = shortcut.windowTitles
        guard !titles.isEmpty else {
            logger.warning("Empty window title list for shortcut")
            return
        }

        // Get the current active window title
        let currentTitle = sourceManager.focusedWindowTitle

        // Find the starting index based on the current window
        let startIndex: Int
        if let currentTitle = currentTitle,
            let currentIndex = titles.firstIndex(of: currentTitle)
        {
            // Start from the next window in the cycle
            startIndex = (currentIndex + 1) % titles.count
        } else {
            // Start from the beginning if current window is not in the list
            startIndex = 0
        }

        // Try to activate windows in order starting from the calculated index
        for offset in 0..<titles.count {
            let index = (startIndex + offset) % titles.count
            let title = titles[index]

            if sourceManager.focusSource(withTitle: title) {
                logger.info("Window focused via shortcut cycle: '\(title)'")
                Task { await sourceManager.updateFocusedSource() }  // TODO: Remove when source observer improves
                return
            }
        }

        logger.warning("Failed to focus any window for shortcut: \(titles.joined(separator: ", "))")
    }
}
