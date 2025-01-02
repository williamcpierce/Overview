/*
 Capture/Services/CaptureConfigurationService.swift
 Overview

 Created by William Pierce on 12/6/24.

 Manages low-level window capture configuration and stream settings optimization,
 providing a reliable foundation for Overview's window preview capabilities through
 efficient ScreenCaptureKit integration.
*/

import ScreenCaptureKit

final class CaptureConfigurationService {
    private let logger = AppLogger.capture

    func createConfiguration(_ window: SCWindow, frameRate: Double) -> (
        SCStreamConfiguration, SCContentFilter
    ) {
        logger.debug(
            """
            Creating configuration for window:
            Title: '\(window.title ?? "unknown")'
            Frame: \(window.frame)
            Frame rate: \(frameRate)
            """
        )

        let config = SCStreamConfiguration()
        
        // Get the scaling factor from the main screen
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 1.0
        
        // Get the actual pixel dimensions of the window
        let width = Int(window.frame.width * scaleFactor)
        let height = Int(window.frame.height * scaleFactor)
        
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.queueDepth = 3
        config.showsCursor = false
        
        // Set pixel format for better compatibility
        config.pixelFormat = kCVPixelFormatType_32BGRA
        
        let filter = SCContentFilter(desktopIndependentWindow: window)

        logger.info("""
            Configuration created successfully:
            Width: \(width)
            Height: \(height)
            Scale factor: \(scaleFactor)
            """)
        return (config, filter)
    }

    func updateConfiguration(_ stream: SCStream?, _ window: SCWindow, frameRate: Double)
        async throws
    {
        logger.debug("Updating stream configuration: frameRate=\(frameRate)")

        guard let stream = stream else {
            logger.warning("Cannot update configuration: stream is nil")
            return
        }

        let (config, filter) = createConfiguration(window, frameRate: frameRate)

        do {
            try await stream.updateConfiguration(config)
            try await stream.updateContentFilter(filter)
            logger.info("""
                Stream configuration updated successfully:
                Width: \(config.width)
                Height: \(config.height)
                """)
        } catch {
            logger.error("Failed to update stream: \(error.localizedDescription)")
            throw error
        }
    }
}
