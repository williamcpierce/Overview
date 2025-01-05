/*
 Capture/Services/CaptureConfigurationService.swift
 Overview

 Created by William Pierce on 12/6/24.

 Handles stream configuration for window capture, including frame rate
 and filter settings.
*/

import ScreenCaptureKit

final class CaptureConfigurationService {
    // MARK: - Dependencies
    private let logger = AppLogger.capture

    // MARK: - Configuration Management

    func createConfiguration(_ window: SCWindow, frameRate: Double) -> (
        SCStreamConfiguration, SCContentFilter
    ) {
        logger.debug(
            "Creating configuration for window: '\(window.title ?? "unknown")', frameRate: \(frameRate)"
        )

        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.queueDepth = 3
        config.showsCursor = false

        let filter = SCContentFilter(desktopIndependentWindow: window)

        logger.info("Configuration created successfully")
        return (config, filter)
    }

    func updateConfiguration(_ stream: SCStream?, _ window: SCWindow, frameRate: Double)
        async throws
    {
        logger.debug("Updating stream configuration: frameRate=\(frameRate)")

        guard let stream: SCStream = stream else {
            logger.warning("Cannot update configuration: stream is nil")
            return
        }

        let (config, filter) = createConfiguration(window, frameRate: frameRate)

        do {
            try await stream.updateConfiguration(config)
            try await stream.updateContentFilter(filter)
            logger.info("Stream configuration updated successfully")
        } catch {
            logger.error("Failed to update stream: \(error.localizedDescription)")
            throw error
        }
    }
}
