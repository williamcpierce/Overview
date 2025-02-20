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
                self.activateSourceWindow(for: shortcut)
            }
        }
    }

    private func activateSourceWindow(for shortcut: ShortcutItem) {
        let titles = shortcut.windowTitles
        guard !titles.isEmpty else {
            logger.warning("Empty window title list for shortcut")
            return
        }

        let currentTitle = sourceManager.getActiveWindowTitle()

        let startIndex: Int
        if let currentTitle = currentTitle,
            let currentIndex = titles.firstIndex(of: currentTitle)
        {
            startIndex = (currentIndex + 1) % titles.count
        } else {
            startIndex = 0
        }

        // Try to activate windows in order starting from the calculated index
        for offset in 0..<titles.count {
            let index = (startIndex + offset) % titles.count
            let title = titles[index]

            if sourceManager.focusSource(withTitle: title) {
                logger.info("Window focused via shortcut cycle: '\(title)'")
                return
            }
        }

        logger.warning("Failed to focus any window for shortcut: \(titles.joined(separator: ", "))")
    }
}
