/*
 Update/UpdateManager.swift
 Overview

 Created by William Pierce on 2/10/25.

 Coordinates update checking and status tracking through the Sparkle
 framework integration.
*/

import Sparkle
import SwiftUI

@MainActor
final class UpdateManager: ObservableObject {
    // Dependencies
    private let logger = AppLogger.settings
    private let updaterController: SPUStandardUpdaterController

    // Published State
    @Published private(set) var updater: SPUUpdater
    @Published private(set) var canCheckForUpdates: Bool = false

    init() {
        logger.debug("Initializing update manager")

        // Initialize the updater controller first
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updater = updaterController.updater

        // Configure update status binding
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)

        logger.debug("Update manager initialization complete")
    }

    // MARK: - Public Methods

    func checkForUpdates() {
        logger.info("Initiating update check")
        updater.checkForUpdates()
    }
}
