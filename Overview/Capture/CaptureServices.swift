/*
 CaptureServices.swift
 Overview

 Created by William Pierce on 12/6/24.

 Manages low-level window capture configuration and stream settings optimization,
 providing a reliable foundation for Overview's window preview capabilities through
 efficient ScreenCaptureKit integration.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import ScreenCaptureKit

// MARK: - Stream Configuration Service

/// Manages capture stream settings optimization and dynamic configuration updates
///
/// Key responsibilities:
/// - Creates optimized stream configurations for window capture
/// - Manages frame rate and quality settings adaptation
/// - Handles dynamic stream updates during active capture
/// - Maintains capture stability across configuration changes
///
/// Coordinates with:
/// - CaptureManager: Provides high-level capture session management
/// - CaptureEngine: Manages low-level stream operations
/// - AppSettings: Receives frame rate and quality preferences
/// - PreviewAccessor: Aligns capture dimensions with preview scaling
class StreamConfigurationService {
    // MARK: - Properties

    /// System logger for capture configuration operations
    private let logger = AppLogger.capture

    // MARK: - Public Methods

    /// Creates optimized stream configuration and content filter for window capture
    ///
    /// Flow:
    /// 1. Configures capture dimensions to match source window
    /// 2. Sets frame timing parameters for desired refresh rate
    /// 3. Optimizes queue depth for smooth playback
    /// 4. Creates precise window content filter
    ///
    /// - Parameters:
    ///   - window: Target window to capture
    ///   - frameRate: Desired capture frequency in FPS
    /// - Returns: Tuple containing stream configuration and content filter
    ///
    /// - Warning: Frame rate changes require full stream reconfiguration
    func createConfiguration(_ window: SCWindow, frameRate: Double) -> (
        SCStreamConfiguration, SCContentFilter
    ) {
        logger.debug(
            "Creating configuration for window: '\(window.title ?? "unknown")', frameRate: \(frameRate)"
        )

        let config = SCStreamConfiguration()

        // Context: Match stream resolution to window size for optimal quality
        // Using Int conversion to handle potential dimension precision loss
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)

        // Context: Frame interval controls capture rate and resource usage
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))

        // Context: Queue depth of 3 provides balance between latency and smooth playback
        config.queueDepth = 3

        // Context: Cursor adds visual noise to previews
        config.showsCursor = false

        let filter = SCContentFilter(desktopIndependentWindow: window)

        logger.info("Configuration created successfully")
        return (config, filter)
    }

    /// Updates active stream configuration while maintaining capture
    ///
    /// Flow:
    /// 1. Creates new configuration with current settings
    /// 2. Updates stream configuration atomically
    /// 3. Updates content filter to maintain window tracking
    /// 4. Validates successful application of changes
    ///
    /// - Parameters:
    ///   - stream: Active capture stream to update
    ///   - window: Current target window
    ///   - frameRate: Desired capture frequency
    ///
    /// - Throws: SCStream configuration or filter update errors
    /// - Warning: Frame rate changes require full stream reconfiguration
    /// - Warning: Updates must apply configuration before filter
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
            // Context: Order matters - must update configuration before filter
            // to maintain stream stability during transition
            try await stream.updateConfiguration(config)
            try await stream.updateContentFilter(filter)
            logger.info("Stream configuration updated successfully")
        } catch {
            logger.error("Failed to update stream: \(error.localizedDescription)")
            throw error
        }
    }
}
