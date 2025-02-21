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
    private var lastActivationTime: TimeInterval = 0
    private let activationThrottle: TimeInterval = 0.1  // 100ms throttle
    
    // Window cycling state
    private var cyclingShortcut: ShortcutItem?
    private var cyclingIndex: Int = 0

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
                self.handleShortcutActivation(shortcut)
            }
        }
    }

    // MARK: - Window Activation

    private func handleShortcutActivation(_ shortcut: ShortcutItem) {
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastActivation = currentTime - lastActivationTime
        
        // Check if we're continuing a cycle or starting a new one
        if timeSinceLastActivation > activationThrottle || cyclingShortcut?.id != shortcut.id {
            // Start new cycle
            startNewCycle(shortcut)
        } else {
            // Continue existing cycle
            continueCycle()
        }
        
        lastActivationTime = currentTime
    }
    
    private func startNewCycle(_ shortcut: ShortcutItem) {
        let titles = shortcut.windowTitles
        guard !titles.isEmpty else {
            logger.warning("Empty window title list for shortcut")
            return
        }

        // Set up new cycle
        cyclingShortcut = shortcut
        
        // Find starting index
        let currentTitle = sourceManager.focusedWindow.title
        if let currentIndex = titles.firstIndex(of: currentTitle) {
            cyclingIndex = (currentIndex + 1) % titles.count
        } else {
            cyclingIndex = 0
        }
        
        // Activate first window in cycle
        activateWindow(at: cyclingIndex)
    }
    
    private func continueCycle() {
        guard let shortcut = cyclingShortcut else { return }
        
        // Move to next window in cycle
        cyclingIndex = (cyclingIndex + 1) % shortcut.windowTitles.count
        activateWindow(at: cyclingIndex)
    }
    
    private func activateWindow(at index: Int) {
        guard let shortcut = cyclingShortcut else { return }
        let title = shortcut.windowTitles[index]
        
        if sourceManager.focusSource(withTitle: title) {
            logger.info("Window focused via shortcut cycle: '\(title)'")
        } else {
            // If window focus fails, try next window
            cyclingIndex = (cyclingIndex + 1) % shortcut.windowTitles.count
            if cyclingIndex != index {  // Prevent infinite loop
                activateWindow(at: cyclingIndex)
            } else {
                logger.warning("Failed to focus any window for shortcut: \(shortcut.windowTitles.joined(separator: ", "))")
            }
        }
    }
}
