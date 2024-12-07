/*
 CaptureTaskManager.swift
 Overview

 Created by William Pierce on 12/5/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import Foundation
import ScreenCaptureKit
import OSLog

protocol CaptureTaskManager: AnyObject {
    var onFrame: (CapturedFrame) -> Void { get set }
    var onError: (Error) -> Void { get set }
    
    func startCapture(using engine: CaptureEngine, config: SCStreamConfiguration, filter: SCContentFilter) async
    func stopCapture() async
}

class DefaultCaptureTaskManager: CaptureTaskManager {
    private var captureTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.Overview.CaptureTaskManager", category: "CaptureTask")
    
    var onFrame: (CapturedFrame) -> Void = { _ in }
    var onError: (Error) -> Void = { _ in }
    
    @MainActor
    func startCapture(using engine: CaptureEngine, config: SCStreamConfiguration, filter: SCContentFilter) async {
        captureTask?.cancel()
        
        let frameStream = engine.startCapture(configuration: config, filter: filter)
        
        captureTask = Task { @MainActor in
            do {
                for try await frame in frameStream {
                    onFrame(frame)
                }
            } catch {
                onError(error)
                logger.error("Capture stream failed: \(error.localizedDescription)")
            }
        }
    }
    
    func stopCapture() async {
        captureTask?.cancel()
        captureTask = nil
    }
}
