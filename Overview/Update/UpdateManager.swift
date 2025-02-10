/*
 Update/UpdateManager.swift
 Overview

 Created by William Pierce on 2/10/25.
*/

import Sparkle
import SwiftUI

@MainActor
final class UpdateManager: ObservableObject {
    // Dependencies
    private let logger = AppLogger.settings

    // Published State
    @Published var updater: SPUUpdater
    @Published var canCheckForUpdates: Bool = false

    // Private State
    let updaterController: SPUStandardUpdaterController

    init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updater = updaterController.updater
        self.updater
            .publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        logger.info("Initiating update check")
        updater.checkForUpdates()
    }
}
