/*
 Capture/Services/CaptureAvailabilityService.swift
 Overview

 Created by William Pierce on 12/15/24.

 Manages screen recording permissions and source window availability checks.
*/

import ScreenCaptureKit

final class CaptureAvailabilityService {
    // Dependencies
    private let logger = AppLogger.capture

    // Constants
    private enum SetupKeys {
        static let hasCompletedSetup: String = "hasCompletedSetup"
    }

    func requestPermission(duringSetup: Bool = false) async throws {
        if !duringSetup && !UserDefaults.standard.bool(forKey: SetupKeys.hasCompletedSetup) {
            logger.debug("Skipping permission request: setup not completed")
            return
        }

        logger.info("Requesting screen recording permission")

        do {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            logger.info("Screen recording permission granted")
        } catch {
            logger.logError(error, context: "Screen recording permission denied")
            throw CaptureError.permissionDenied
        }
    }

    func getAvailableSources() async throws -> [SCWindow] {
        guard UserDefaults.standard.bool(forKey: SetupKeys.hasCompletedSetup) else {
            logger.debug("Skipping source retrieval: setup not completed")
            return []
        }

        do {
            let content: SCShareableContent = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: false)

            return content.windows
        } catch {
            logger.logError(error, context: "Failed to get source windows")
            throw error
        }
    }
}
