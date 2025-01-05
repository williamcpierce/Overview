/*
 Preview/PreviewManager.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages the initialization and coordination of preview windows,
 handling capture system setup and window list management.
*/

import Combine
import ScreenCaptureKit
import SwiftUI

@MainActor
final class PreviewManager: ObservableObject {
    // MARK: - Published State
    @Published private(set) var availableWindows: [SCWindow] = []
    @Published private(set) var isInitializing: Bool = true
    @Published private(set) var windowListVersion: UUID = UUID()
    @Published var editModeEnabled: Bool = false

    // MARK: - Dependencies
    @ObservedObject private var windowManager: WindowManager
    private let logger = AppLogger.interface

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        logger.debug("Initializing preview manager")
    }

    // MARK: - Capture System Management

    func initializeCaptureSystem(_ captureManager: CaptureManager) async {
        do {
            logger.info("Starting capture system initialization")
            try await captureManager.requestPermission()
            await updateAvailableWindows()
            completeInitialization()
        } catch {
            handleInitializationError(error)
        }
    }

    private func completeInitialization() {
        logger.info("Capture system initialization completed")
        isInitializing = false
    }

    private func handleInitializationError(_ error: Error) {
        logger.logError(error, context: "Capture system initialization failed")
        isInitializing = false
    }

    // MARK: - Window Preview Management

    func startWindowPreview(captureManager: CaptureManager, window: SCWindow?) {
        guard let selectedWindow: SCWindow = window else {
            logger.warning("Cannot start preview: no window selected")
            return
        }

        logger.debug("Starting preview for window: '\(selectedWindow.title ?? "Untitled")'")
        captureManager.selectedWindow = selectedWindow

        Task {
            do {
                try await captureManager.startCapture()
                logger.info("Preview started successfully")
            } catch {
                logger.logError(error, context: "Preview initialization failed")
            }
        }
    }

    // MARK: - Window List Management

    func updateAvailableWindows() async {
        do {
            let windows = try await windowManager.getFilteredWindows()
            availableWindows = windows
            windowListVersion = UUID()

            logger.debug("Window list updated: \(windows.count) available windows")
        } catch {
            logger.logError(error, context: "Failed to retrieve available windows")
        }
    }
}
