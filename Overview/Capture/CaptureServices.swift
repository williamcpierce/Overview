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
import OSLog
import ScreenCaptureKit

class StreamConfigurationService {
    func createConfiguration(_ window: SCWindow, frameRate: Double) -> (SCStreamConfiguration, SCContentFilter) {
        let config = SCStreamConfiguration()
        
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.queueDepth = 3
        config.showsCursor = false
        
        let filter = SCContentFilter(desktopIndependentWindow: window)
        return (config, filter)
    }
    
    func updateConfiguration(_ stream: SCStream?, _ window: SCWindow, frameRate: Double) async throws {
        guard let stream = stream else { return }
        let (config, filter) = createConfiguration(window, frameRate: frameRate)
        
        try await stream.updateConfiguration(config)
        try await stream.updateContentFilter(filter)
    }
}

class ShareableContentService {
    func requestPermission() async throws {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }
    
    func getAvailableWindows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.windows
    }
}
