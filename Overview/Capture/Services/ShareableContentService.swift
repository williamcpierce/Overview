/*
 Capture/Services/ShareableContentService.swift
 Overview

 Created by William Pierce on 12/15/24.
*/

import ScreenCaptureKit

final class ShareableContentService {
    static let shared = ShareableContentService()

    private let logger = AppLogger.capture

    func requestPermission() async throws {
        logger.info("Requesting screen recording permission")

        do {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            logger.info("Screen recording permission granted")
        } catch {
            logger.error("Screen recording permission denied: \(error.localizedDescription)")
            throw CaptureError.permissionDenied
        }
    }

    func getAvailableWindows() async throws -> [SCWindow] {
        logger.debug("Fetching available windows")

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)

            logger.debug("Retrieved \(content.windows.count) available windows")
            return content.windows
        } catch {
            logger.error("Failed to get windows: \(error.localizedDescription)")
            throw error
        }
    }
}
