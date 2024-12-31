/*
 Preview/PreviewManager.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages multiple window preview instances and coordinates their lifecycle,
 providing centralized control of capture sessions and edit mode state.
 Core orchestrator for Overview's window preview system.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class PreviewManager: ObservableObject {
    @Published private(set) var isInitializing: Bool = true
    @Published var editModeEnabled: Bool = false

    private let logger = AppLogger.interface

    // MARK: - Capture System Management

    func initializeCaptureSystem(captureManager: CaptureManager) async {
        do {
            try await requestCapturePermission(for: captureManager)
            await updateAvailableWindows(using: captureManager)
            completeInitialization()
        } catch {
            handleInitializationError(error)
        }
    }

    private func requestCapturePermission(for captureManager: CaptureManager) async throws {
        try await captureManager.requestPermission()
    }

    private func updateAvailableWindows(using captureManager: CaptureManager) async {
        await captureManager.updateAvailableWindows()
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

    func startWindowPreview(using captureManager: CaptureManager, for window: SCWindow?) {
        guard let selectedWindow = window else { return }

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
}
