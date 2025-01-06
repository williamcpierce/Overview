/*
 Hotkey/HotkeyManager.swift
 Overview

 Created by William Pierce on 12/9/24.

 Coordinates hotkey registration and source window management, handling
 keyboard shortcut events and source window focus operations.
*/

import SwiftUI

@MainActor
final class HotkeyManager: ObservableObject {
    // MARK: - Dependencies

    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var sourceManager: SourceManager
    let hotkeyService: HotkeyService = HotkeyService.shared
    private let logger = AppLogger.hotkeys

    init(appSettings: AppSettings, sourceManager: SourceManager) {
        logger.debug("Initializing HotkeyManager")
        self.appSettings = appSettings
        self.sourceManager = sourceManager

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
        hotkeyService.registerCallback(owner: self) { [weak self] sourceTitle in
            Task { @MainActor in
                self?.activateSourceWithTitle(sourceTitle)
            }
        }
    }

    // MARK: - Source Window Activation

    private func activateSourceWithTitle(_ sourceTitle: String) {
        logger.debug("Processing source window activation: '\(sourceTitle)'")

        let activationSucceeded: Bool = sourceManager.focusSource(withTitle: sourceTitle)

        if activationSucceeded {
            logger.info("Source window focus successful: '\(sourceTitle)'")
        } else {
            logger.warning("Source window focus failed: '\(sourceTitle)'")
        }
    }
}
