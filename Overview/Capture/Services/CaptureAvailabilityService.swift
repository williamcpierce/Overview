/*
 Capture/Services/CaptureAvailabilityService.swift
 Overview

 Created by William Pierce on 12/15/24.

 Manages screen recording permissions and window availability checks.
*/

import ScreenCaptureKit

final class CaptureAvailabilityService {
    private let logger = AppLogger.capture

    func requestPermission() async throws {
        logger.info("Requesting screen recording permission")

        do {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            logger.info("Screen recording permission granted")
        } catch {
            logger.logError(error, context: "Screen recording permission denied")
            throw CaptureError.permissionDenied
        }
    }

    func getAvailableWindows() async throws -> [SCWindow] {
        logger.debug("Fetching available windows")

        do {
            let content: SCShareableContent = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: false)

            logger.debug("Retrieved \(content.windows.count) available windows")
            return content.windows
        } catch {
            logger.logError(error, context: "Failed to get windows")
            throw error
        }
    }
}
