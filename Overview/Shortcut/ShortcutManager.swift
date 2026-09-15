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
    private var previewManager: PreviewManager
    private let logger = AppLogger.shortcuts

    // Published State
    @Published var shortcutStorage: ShortcutStorage

    // Private State
    private var registeredNames = Set<KeyboardShortcuts.Name>()
    private var cancellables = Set<AnyCancellable>()

    init(sourceManager: SourceManager, previewManager: PreviewManager) {
        self.sourceManager = sourceManager
        self.previewManager = previewManager
        self.shortcutStorage = ShortcutStorage()
        setupShortcuts()
    }

    private func setupShortcuts() {
        setupHideAllPreviewsShortcut()

        shortcutStorage.shortcuts.forEach { shortcut in
            if shortcut.isEnabled {
                setupShortcutObserver(for: shortcut)
            } else {
                KeyboardShortcuts.disable(shortcut.shortcutName)
            }
        }

        shortcutStorage.$shortcuts
            .dropFirst()
            .sink { [weak self] shortcuts in
                if shortcuts.isEmpty {
                    self?.logger.debug("Shortcuts reset detected, clearing observers")
                }

                let currentNames = Set(shortcuts.map(\.shortcutName))
                for name in self?.registeredNames.subtracting(currentNames) ?? [] {
                    KeyboardShortcuts.disable(name)
                }
                self?.registeredNames = currentNames
                shortcuts.forEach { shortcut in
                    if shortcut.isEnabled {
                        self?.setupShortcutObserver(for: shortcut)
                    } else {
                        KeyboardShortcuts.disable(shortcut.shortcutName)
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func setupHideAllPreviewsShortcut() {
        KeyboardShortcuts.onKeyDown(for: .toggleHideAllPreviews) { [weak self] in
            Task { @MainActor in
                self?.previewManager.hideAllPreviews.toggle()
            }
        }
    }

    private func setupShortcutObserver(for shortcut: Shortcut) {
        guard shortcut.isEnabled else { return }
        registeredNames.insert(shortcut.shortcutName)
        KeyboardShortcuts.onKeyDown(for: shortcut.shortcutName) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.activateSourceWindow(for: shortcut)
            }
        }
    }

    private func activateSourceWindow(for shortcut: Shortcut) {
        Task {
            _ = try? await sourceManager.getAvailableSources()
            let current = sourceManager.sources.first {
                $0.windowID == sourceManager.focusedWindowID
            }?.title ?? sourceManager.sources.first {
                $0.owningApplication?.processID == sourceManager.focusedProcessId &&
                sourceManager.sources.filter { candidate in
                    candidate.owningApplication?.processID == sourceManager.focusedProcessId
                }.count == 1
            }?.title
            for title in SourceResolver.cycle(shortcut.windowTitles, after: current) {
                if focusWindow(withTitle: title) { return }
            }
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
    
    func resetShortcuts() {
        logger.debug("Resetting shortcut manager")
        shortcutStorage.resetToDefaults()
        KeyboardShortcuts.reset(.toggleHideAllPreviews)
        self.objectWillChange.send()
        logger.info("Shortcut manager reset completed")
    }
}
