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

    func getAvailableSources() async throws -> [SCWindow] {
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
