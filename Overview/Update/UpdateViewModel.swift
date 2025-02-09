/*
 Update/UpdateViewModel.swift
 Overview

 Created by William Pierce on 2/4/25.
*/

import Sparkle
import SwiftUI

final class UpdateViewModel: ObservableObject {
    //Dependencies
    private let updater: SPUUpdater
    private let logger = AppLogger.settings

    // Published State
    @Published var canCheckForUpdates: Bool = false

    init(updater: SPUUpdater) {
        self.updater = updater
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        logger.info("Initiating update check")
        updater.checkForUpdates()
    }
}
