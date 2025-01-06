/*
 Hotkey/HotkeyManager.swift
 Overview

 Created by William Pierce on 12/9/24.

 Coordinates hotkey registration and window management, handling
 keyboard shortcut events and window focus operations.
*/

import SwiftUI

@MainActor
final class HotkeyManager: ObservableObject {
    // MARK: - Dependencies

    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var windowManager: WindowManager
    let hotkeyService: HotkeyService = HotkeyService.shared
    private let logger = AppLogger.hotkeys

    init(appSettings: AppSettings, windowManager: WindowManager) {
        logger.debug("Initializing HotkeyManager")
        self.appSettings = appSettings
        self.windowManager = windowManager

        do {
            try hotkeyService.initializeEventHandler()
            logger.debug("Event handler configured successfully")
        } catch {
            logger.logError(error, context: "Event handler initialization failed")
        }
        configureHotkeyEventHandling()
    }

    deinit {
        logger.debug("Cleaning up HotkeyManager resources")
        hotkeyService.removeCallback(for: self)
        logger.debug("Cleanup completed")
    }

    // MARK: - Event Configuration

    private func configureHotkeyEventHandling() {
        hotkeyService.registerCallback(owner: self) { [weak self] windowTitle in
            Task { @MainActor in
                self?.activateWindowWithTitle(windowTitle)
            }
        }
    }

    // MARK: - Window Activation

    private func activateWindowWithTitle(_ windowTitle: String) {
        logger.debug("Processing window activation: '\(windowTitle)'")

        let activationSucceeded: Bool = windowManager.focusWindow(withTitle: windowTitle)

        if activationSucceeded {
            logger.info("Window focus successful: '\(windowTitle)'")
        } else {
            logger.warning("Window focus failed: '\(windowTitle)'")
        }
    }
}
