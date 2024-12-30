/*
 Preview/PreviewManager.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages multiple window preview instances and coordinates their lifecycle,
 providing centralized control of capture sessions and edit mode state.
 Core orchestrator for Overview's window preview system.
*/

import SwiftUI
import ScreenCaptureKit

@MainActor
final class PreviewManager: ObservableObject {
    @Published var editModeEnabled: Bool = false
    @Published var isInitializing: Bool = true
    
    private let logger = AppLogger.interface

    init() {
    }
    
    func initializeCaptureSystem(captureManager: CaptureManager) async {
        do {
            try await captureManager.requestPermission()
            await captureManager.updateAvailableWindows()

            logger.info("Capture setup completed successfully")
            isInitializing = false
        } catch {
            logger.logError(
                error,
                context: "Screen recording permission request")
            isInitializing = false
        }
    }
    
    func initiateWindowPreview(captureManager: CaptureManager, window: SCWindow?) {
        guard window != nil else { return }
        
        logger.debug("Starting preview for window: '\(window?.title ?? "Untitled")'")

        captureManager.selectedWindow = window
//        selectedWindowSize = CGSize(width: window.frame.width, height: window.frame.height)

        Task {
            do {
                try await captureManager.startCapture()
                logger.info("Preview started successfully")
            } catch {
                logger.logError(
                    error,
                    context: "Starting window preview")
            }
        }
    }
}
