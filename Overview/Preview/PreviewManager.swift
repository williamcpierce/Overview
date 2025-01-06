/*
 Preview/PreviewManager.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages the initialization and coordination of preview windows,
 handling capture system setup and source window list management.
*/

import Combine
import ScreenCaptureKit
import SwiftUI

@MainActor
final class PreviewManager: ObservableObject {
    // MARK: - Published State
    @Published private(set) var availableSources: [SCWindow] = []
    @Published private(set) var isInitializing: Bool = true
    @Published private(set) var sourceListVersion: UUID = UUID()
    @Published var editModeEnabled: Bool = false

    // MARK: - Dependencies
    @ObservedObject private var sourceManager: SourceManager
    private let logger = AppLogger.interface

    init(sourceManager: SourceManager) {
        self.sourceManager = sourceManager
        logger.debug("Initializing preview manager")
    }

    // MARK: - Capture System Management

    func initializeCaptureSystem(_ captureManager: CaptureManager) async {
        do {
            logger.info("Starting capture system initialization")
            try await captureManager.requestPermission()
            await updateAvailableSources()
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

    // MARK: - Source Preview Management

    func startSourcePreview(captureManager: CaptureManager, source: SCWindow?) {
        guard let selectedSource: SCWindow = source else {
            logger.warning("Cannot start preview: no source window selected")
            return
        }

        logger.debug("Starting preview for source window: '\(selectedSource.title ?? "Untitled")'")
        captureManager.selectedSource = selectedSource

        Task {
            do {
                try await captureManager.startCapture()
                logger.info("Preview started successfully")
            } catch {
                logger.logError(error, context: "Preview initialization failed")
            }
        }
    }

    // MARK: - Source List Management

    func updateAvailableSources() async {
        do {
            let sources = try await sourceManager.getFilteredSources()
            availableSources = sources
            sourceListVersion = UUID()

            logger.debug("Source window list updated: \(sources.count) available sources")
        } catch {
            logger.logError(error, context: "Failed to retrieve available source windows")
        }
    }
}
