/*
 CaptureTaskManager.swift
 Overview

 Created by William Pierce on 12/5/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit

class CaptureTaskManager {
    private var captureTask: Task<Void, Never>?
    
    var onFrame: (CapturedFrame) -> Void = { _ in }
    var onError: (Error) -> Void = { _ in }
    
    @MainActor
    func startCapture(frameStream: AsyncThrowingStream<CapturedFrame, Error>) async {
        captureTask?.cancel()
        
        captureTask = Task { @MainActor in
            do {
                for try await frame in frameStream {
                    onFrame(frame)
                }
            } catch {
                onError(error)
            }
        }
    }
    
    func stopCapture() async {
        captureTask?.cancel()
        captureTask = nil
    }
}
