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
    // Published State
    @Published private(set) var availableSources: [SCWindow] = []
    @Published private(set) var sourceListVersion: UUID = UUID()
    @Published var editModeEnabled: Bool = false
    @Published var hideAllPreviews: Bool = false

    // Dependencies
    private var sourceManager: SourceManager
    private var permissionManager: PermissionManager
    private let logger = AppLogger.interface

    // Private State
    private var subscriptions = Set<AnyCancellable>()

    init(sourceManager: SourceManager, permissionManager: PermissionManager) {
        self.sourceManager = sourceManager
        self.permissionManager = permissionManager
        sourceManager.$sources.sink { [weak self] sources in
            guard let self else { return }
            self.availableSources = sourceManager.filtered(sources)
        }.store(in: &subscriptions)
        logger.debug("Initializing preview manager")
    }

    func initializeCaptureSystem(_ captureCoordinator: CaptureCoordinator) async {
        do {
            logger.debug("Starting capture system initialization")
            try await permissionManager.ensurePermission()
            await updateAvailableSources()
            logger.debug("Capture system initialization completed")

        } catch {
            logger.logError(error, context: "Capture system initialization failed")
        }
    }

    func startSourcePreview(captureCoordinator: CaptureCoordinator, source: SCWindow?) {
        guard let selectedSource: SCWindow = source else {
            logger.warning("Cannot start preview: no source window selected")
            return
        }

        logger.debug("Starting preview for source window: '\(selectedSource.title ?? "Untitled")'")
        captureCoordinator.selectedSource = selectedSource
        if let identity = selectedSource.identity {
            // Source list selection seeds or replaces a one-member group.
            captureCoordinator.setSources([identity])
        }

        Task {
            do {
                try await captureCoordinator.startCapture()
                logger.info("Preview started successfully")
            } catch {
                logger.logError(error, context: "Preview initialization failed")
            }
        }
    }

    func updateAvailableSources() async {
        if permissionManager.permissionStatus != .granted {
            logger.debug("Skipping source update: permission not granted")
            return
        }

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
