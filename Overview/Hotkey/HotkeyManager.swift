/*
 Hotkey/HotkeyManager.swift
 Overview

 Created by William Pierce on 12/9/24.

 Coordinates window focusing operations through keyboard shortcuts, serving as the bridge
 between the HotkeyService and WindowManager for hotkey-triggered window activation.
 Provides reliable window focus operations in response to global keyboard events.
*/

import SwiftUI

@MainActor
final class HotkeyManager: ObservableObject {
    init() {
        configureHotkeyEventHandling()
    }

    private func configureHotkeyEventHandling() {
        AppLogger.hotkeys.debug("Initializing HotkeyManager")

        // Weak reference prevents retain cycles in callback chain
        HotkeyService.shared.registerCallback(owner: self) { [weak self] windowTitle in
            Task { @MainActor in
                self?.activateWindowWithTitle(windowTitle)
            }
        }

        AppLogger.hotkeys.info("HotkeyManager successfully initialized")
    }

    private func activateWindowWithTitle(_ windowTitle: String) {
        AppLogger.hotkeys.debug("Focusing window: '\(windowTitle)'")

        let activationSucceeded = WindowManager.shared.focusWindow(withTitle: windowTitle)

        if activationSucceeded {
            AppLogger.hotkeys.info("Successfully focused window: '\(windowTitle)'")
        } else {
            AppLogger.hotkeys.warning("Failed to focus window: '\(windowTitle)'")
        }
    }

    deinit {
        AppLogger.hotkeys.debug("Cleaning up HotkeyManager")
        HotkeyService.shared.removeCallback(for: self)
        AppLogger.hotkeys.info("HotkeyManager cleanup completed")
    }
}
