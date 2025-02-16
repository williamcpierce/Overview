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
final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    // Dependencies
    private let logger = AppLogger.settings
    private let updaterController: SPUStandardUpdaterController

    // Published State
    @Published private(set) var updater: SPUUpdater
    @Published private(set) var canCheckForUpdates: Bool = false

    // Update Settings
    @AppStorage(UpdateSettingsKeys.enableBetaUpdates)
    var enableBetaUpdates = UpdateSettingsKeys.defaults.enableBetaUpdates

    override init() {
        logger.debug("Initializing update manager")

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updater = updaterController.updater

        super.init()

        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)

        logger.debug("Update manager initialization complete")
    }

    // MARK: - Public Methods

    func checkForUpdates() {
        logger.info("Initiating update check")
        updater.checkForUpdates()
    }

    // MARK: - SPUUpdaterDelegate

    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        if UserDefaults.standard.bool(forKey: UpdateSettingsKeys.enableBetaUpdates) {
            return Set(["beta"])
        }
        return Set()
    }
}
