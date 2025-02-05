/*
 Update/UpdateManager.swift
 Overview

 Created by William Pierce on 2/4/25.

 Manages automatic software updates using the Sparkle framework.
*/

import Sparkle
import SwiftUI

@MainActor
final class UpdateManager: ObservableObject {
    // Dependencies
    private let logger = AppLogger.settings
    private let updater: SPUUpdater
    private let updaterController: SPUStandardUpdaterController

    // Published State
    @Published private(set) var canCheckForUpdates: Bool = true

    init() {
        // Create standard updater controller
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Get reference to updater
        updater = updaterController.updater

        setupNotifications()
        logger.debug("Update manager initialized")

        // Check for updates on launch
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // Wait 2 seconds after launch
            checkForUpdates()
        }
    }

    // MARK: - Public Interface

    func checkForUpdates() {
        guard canCheckForUpdates else {
            logger.warning("Update check requested while unavailable")
            return
        }

        logger.info("Initiating update check")
        updaterController.checkForUpdates(nil)
    }

    // MARK: - Private Methods

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updaterDidFinishLoadingAndInvalidated),
            name: NSNotification.Name("SUUpdaterDidFinishLoadingAppCast"),
            object: nil
        )
    }

    @objc private func updaterDidFinishLoadingAndInvalidated() {
        canCheckForUpdates = true
        logger.debug("Update checker ready")
    }
}
