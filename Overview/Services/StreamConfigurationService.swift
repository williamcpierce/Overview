/*
 StreamConfigurationService.swift
 Overview

 Created by William Pierce on 12/5/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit
import CoreMedia
import OSLog

protocol StreamConfigurationService {
    func createConfiguration(for window: SCWindow, frameRate: Double) -> SCStreamConfiguration
    func updateConfiguration(_ stream: SCStream?, for window: SCWindow, frameRate: Double) async throws
}

class DefaultStreamConfigurationService: StreamConfigurationService {
    private let logger = Logger(subsystem: "com.Overview.StreamConfigurationService", category: "StreamConfig")
    
    func createConfiguration(for window: SCWindow, frameRate: Double) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.queueDepth = 3
        config.showsCursor = false
        return config
    }
    
    func updateConfiguration(_ stream: SCStream?, for window: SCWindow, frameRate: Double) async throws {
        guard let stream = stream else { return }
        let config = createConfiguration(for: window, frameRate: frameRate)
        try await stream.updateConfiguration(config)
        logger.info("Successfully updated stream configuration with new FPS: \(frameRate)")
    }
}
