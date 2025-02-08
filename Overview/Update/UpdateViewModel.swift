/*
 Update/UpdateViewModel.swift
 Overview
*/

import SwiftUI
import Sparkle

final class UpdateViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private let updater: SPUUpdater
    private let logger = AppLogger.settings
    
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
