/*
 CaptureServices.swift
 Overview

 Created by William Pierce on 12/6/24.

 Provides core services for window capture operations, handling stream configuration,
 window filtering, focus management, and state observation. These services form the
 foundation for Overview's window capture capabilities.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import ScreenCaptureKit

// MARK: - Stream Configuration Service

/// Manages stream configuration and optimization for window capture sessions
///
/// Key responsibilities:
/// - Creates and updates stream configurations based on window properties
/// - Manages frame rate and content filter settings
/// - Ensures optimal capture quality across different window types
/// - Handles dynamic configuration updates during capture
///
/// Coordinates with:
/// - CaptureEngine: Provides configuration for capture stream initialization
/// - AppSettings: Receives frame rate and quality preferences
/// - CaptureManager: Coordinates stream updates during active capture
/// - PreviewAccessor: Aligns capture dimensions with preview window scaling
class StreamConfigurationService {
    // MARK: - Properties

    /// Logger for stream configuration operations
    private let logger = AppLogger.capture

    // MARK: - Public Methods

    /// Creates a new stream configuration and content filter for window capture
    ///
    /// Flow:
    /// 1. Configures stream dimensions matching source window
    /// 2. Applies frame timing based on requested rate
    /// 3. Optimizes queue depth for smooth playback
    /// 4. Creates content filter for precise window bounds
    ///
    /// - Parameters:
    ///   - window: Target window to capture
    ///   - frameRate: Desired capture frequency in frames per second
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

        // Context: Match stream resolution to window for optimal quality
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)

        // Context: Frame interval controls capture rate and resource usage
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))

        // Context: Queue depth of 3 balances latency and smooth playback
        config.queueDepth = 3

        // Context: Cursor adds visual noise to previews
        config.showsCursor = false

        let filter = SCContentFilter(desktopIndependentWindow: window)
        return (config, filter)
    }

    /// Updates an existing stream's configuration while maintaining capture
    ///
    /// Flow:
    /// 1. Generates new configuration with current settings
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
    ///
    /// - Warning: Configuration updates may cause momentary frame drops
    /// - Warning: Order matters - config must be updated before filter
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
            logger.info("Stream configuration updated successfully")
        } catch {
            logger.error("Failed to update stream configuration: \(error.localizedDescription)")
            throw error
        }
    }
}
