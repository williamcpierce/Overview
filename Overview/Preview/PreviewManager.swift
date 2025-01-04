/*
 Preview/PreviewManager.swift
 Overview

 Created by William Pierce on 10/13/24.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class PreviewManager: ObservableObject {
    @Published private(set) var isOverviewActive: Bool = false
    @Published private(set) var isInitializing: Bool = true
    @Published var editModeEnabled: Bool = false
    private let logger = AppLogger.interface

    // MARK: - Capture System Management

    func initializeCaptureSystem(_ captureManager: CaptureManager) async {
        do {
            try await captureManager.requestPermission()
            await captureManager.updateAvailableWindows()
            completeInitialization()
        } catch {
            handleInitializationError(error)
        }
    }

    private func completeInitialization() {
        logger.info("Capture system initialized")
        isInitializing = false
    }

    private func handleInitializationError(_ error: Error) {
        logger.logError(error, context: "Capture system initialization failed")
        isInitializing = false
    }

    // MARK: - Window Preview Management

    func startWindowPreview(captureManager: CaptureManager, window: SCWindow?) {
        guard let selectedWindow: SCWindow = window else { return }

        logger.debug("Initiating preview: '\(selectedWindow.title ?? "Untitled")'")
        captureManager.selectedWindow = selectedWindow

        Task {
            do {
                try await captureManager.startCapture()
                logger.info("Preview started")
            } catch {
                logger.logError(error, context: "Preview initialization failed")
            }
        }
    }

    // MARK: - Overview Focus State Management

    func updateOverviewActive(focusedBundleId: String?) {
        isOverviewActive = focusedBundleId == Bundle.main.bundleIdentifier
        logger.debug("Overview active state updated: \(isOverviewActive)")
    }
}
