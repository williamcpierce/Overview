/*
 Capture/Services/CaptureConfigurationService.swift
 Overview

 Created by William Pierce on 12/6/24.

 Handles stream configuration for source window capture, including frame rate
 and filter settings.
*/

import ScreenCaptureKit

final class CaptureConfigurationService {
    private let logger = AppLogger.capture

    func createConfiguration(_ source: SCWindow, frameRate: Double) -> (
        SCStreamConfiguration, SCContentFilter
    ) {
        logger.debug(
            "Creating configuration for window: '\(source.title ?? "unknown")', frameRate: \(frameRate)"
        )

        let config = SCStreamConfiguration()
        config.width = Int(source.frame.width)
        config.height = Int(source.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.queueDepth = 3
        config.showsCursor = false

        let filter = SCContentFilter(desktopIndependentWindow: source)

        logger.info("Configuration created successfully")
        return (config, filter)
    }

    func updateConfiguration(_ stream: SCStream?, _ source: SCWindow, frameRate: Double)
        async throws
    {
        logger.debug("Updating stream configuration: frameRate=\(frameRate)")

        guard let stream: SCStream = stream else {
            logger.warning("Cannot update configuration: stream is nil")
            return
        }

        let (config, filter) = createConfiguration(source, frameRate: frameRate)

        do {
            try await stream.updateConfiguration(config)
            try await stream.updateContentFilter(filter)
            logger.info("Stream configuration updated successfully")
        } catch {
            logger.logError(error, context: "Failed to update stream")
            throw error
        }
    }
}
