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
    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var windowManager: WindowManager
    
    let hotkeyService = HotkeyService.shared
    private let logger = AppLogger.hotkeys

    init(
        appSettings: AppSettings,
        windowManager: WindowManager
    ) {
        logger.debug("Initializing HotkeyManager")
        self.appSettings = appSettings
        self.windowManager = windowManager
        
        do {
            try hotkeyService.initializeEventHandler()
            logger.debug("HotkeyManager successfully initialized")
        } catch {
            logger.logError(
                error,
                context: "HotkeyManager initialization failed")
        }
        configureHotkeyEventHandling()
    }

    deinit {
        logger.debug("Cleaning up HotkeyManager")
        hotkeyService.removeCallback(for: self)
        logger.debug("HotkeyManager cleanup completed")
    }

    private func configureHotkeyEventHandling() {
        // Weak reference prevents retain cycles in callback chain
        hotkeyService.registerCallback(owner: self) { [weak self] windowTitle in
            Task { @MainActor in
                self?.activateWindowWithTitle(windowTitle)
            }
        }
    }

    private func activateWindowWithTitle(_ windowTitle: String) {
        AppLogger.hotkeys.debug("Focusing window: '\(windowTitle)'")

        let activationSucceeded = windowManager.focusWindow(withTitle: windowTitle)

        if activationSucceeded {
            logger.info("Successfully focused window: '\(windowTitle)'")
        } else {
            logger.warning("Failed to focus window: '\(windowTitle)'")
        }
    }
}
