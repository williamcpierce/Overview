/*
 Preview/PreviewManager.swift
 Overview

 Created by William Pierce on 10/13/24.
*/

import Combine
import ScreenCaptureKit
import SwiftUI

@MainActor
final class PreviewManager: ObservableObject {
    @ObservedObject private var windowManager: WindowManager
    @Published private(set) var availableWindows: [SCWindow] = []
    @Published private(set) var isInitializing: Bool = true
    @Published private(set) var windowListVersion: UUID = UUID()
    @Published var editModeEnabled: Bool = false

    private let logger = AppLogger.interface

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    // MARK: - Capture System Management

    func initializeCaptureSystem(_ captureManager: CaptureManager) async {
        do {
            try await captureManager.requestPermission()
            await updateAvailableWindows()
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

    // MARK: - Window List Management

    func updateAvailableWindows() async {
        do {
            availableWindows = try await windowManager.getFilteredWindows()
            windowListVersion = UUID()
        } catch {
            logger.logError(error, context: "Failed to get available windows")
        }
    }
}
