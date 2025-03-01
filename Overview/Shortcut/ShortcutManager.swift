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
    private let logger = AppLogger.shortcuts

    // Published State
    @Published var shortcutStorage: ShortcutStorage

    // Private State
    private var cancellables = Set<AnyCancellable>()

    init(sourceManager: SourceManager) {
        self.sourceManager = sourceManager
        self.shortcutStorage = ShortcutStorage()
        setupShortcuts()
    }

    private func setupShortcuts() {
        shortcutStorage.shortcuts.forEach { shortcut in
            setupShortcutObserver(for: shortcut)
        }

        shortcutStorage.$shortcuts
            .dropFirst()
            .sink { [weak self] shortcuts in
                shortcuts.forEach { shortcut in
                    self?.setupShortcutObserver(for: shortcut)
                }
            }
            .store(in: &cancellables)
    }

    private func setupShortcutObserver(for shortcut: Shortcut) {
        KeyboardShortcuts.onKeyDown(for: shortcut.shortcutName) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.activateSourceWindow(for: shortcut)
            }
        }
    }

    private func findCurrentlyFocusedTitle(in titles: [String]) -> String? {
        guard let focusedProcessId = sourceManager.focusedProcessId else {
            logger.debug("No focused process ID found")
            return nil
        }

        logger.debug("Checking for focused window in process: \(focusedProcessId)")

        for (sourceId, title) in sourceManager.sourceTitles
        where sourceId.processID == focusedProcessId {
            if titles.contains(title) {
                logger.debug("Found matching focused title: '\(title)'")
                return title
            }
        }

        return nil
    }

    private func getNextTitle(after currentTitle: String, in titles: [String]) -> String {
        guard let currentIndex = titles.firstIndex(of: currentTitle) else {
            logger.warning("Current title not found in list: '\(currentTitle)'")
            return titles[0]
        }

        let nextIndex: Int = (currentIndex + 1) % titles.count
        let nextTitle: String = titles[nextIndex]
        logger.debug("Next title in cycle: '\(nextTitle)'")
        return nextTitle
    }

    private func activateSourceWindow(for shortcut: Shortcut) {
        let titles = shortcut.windowTitles
        guard !titles.isEmpty else {
            logger.warning("No window titles specified for shortcut")
            return
        }

        /// Find the currently focused window title if it's in our list
        if let currentTitle = findCurrentlyFocusedTitle(in: titles) {
            logger.debug("Currently focused title: '\(currentTitle)'")

            /// Try to focus windows starting after the current one
            let nextTitle = getNextTitle(after: currentTitle, in: titles)
            let remainingTitles = titles.suffix(from: (titles.firstIndex(of: nextTitle) ?? 0))

            for title in remainingTitles {
                if focusWindow(withTitle: title) {
                    return
                }
            }

            /// If we haven't found a window yet, wrap around to the beginning
            for title in titles.prefix(upTo: (titles.firstIndex(of: currentTitle) ?? 0)) {
                if focusWindow(withTitle: title) {
                    return
                }
            }

            logger.warning("No other focusable windows found in cycle")
        } else {
            logger.debug("Current window not in shortcut list, starting from beginning")
            for title in titles {
                if focusWindow(withTitle: title) {
                    return
                }
            }
            logger.warning("Failed to focus any window for shortcut: \(titles)")
        }
    }

    private func focusWindow(withTitle title: String) -> Bool {
        let activated = sourceManager.focusSource(withTitle: title)
        if activated {
            logger.info("Window focused via shortcut: '\(title)'")
            return true
        }
        logger.debug("Failed to focus window: '\(title)'")
        return false
    }
}
