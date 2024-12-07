/*
 ScreenCaptureManager.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file includes code derived from Apple Inc.'s ScreenRecorder code sample,
 which is licensed under the MIT License. See LICENSE.md for details.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file in the root of this project.
*/

import ScreenCaptureKit
import OSLog

/// A structure that contains the video data to render.
struct CapturedFrame {
    static let invalid = CapturedFrame(surface: nil, contentRect: .zero, contentScale: 0, scaleFactor: 0)
    
    let surface: IOSurface?
    let contentRect: CGRect
    let contentScale: CGFloat
    let scaleFactor: CGFloat
    
    var size: CGSize { contentRect.size }
}

/// An object that wraps an instance of `SCStream`, and returns its results as an `AsyncThrowingStream`.
class CaptureEngine: NSObject, @unchecked Sendable {
    private let logger = Logger()
    private(set) var stream: SCStream?
    private var streamOutput: CaptureEngineStreamOutput?
    private let videoSampleBufferQueue = DispatchQueue(label: "com.example.apple-samplecode.VideoSampleBufferQueue")
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?

    /// Starts capturing the screen content.
    func startCapture(configuration: SCStreamConfiguration, filter: SCContentFilter) -> AsyncThrowingStream<CapturedFrame, Error> {
        AsyncThrowingStream<CapturedFrame, Error> { continuation in
            let streamOutput = CaptureEngineStreamOutput(continuation: continuation)
            self.streamOutput = streamOutput
            streamOutput.capturedFrameHandler = { continuation.yield($0) }

            do {
                self.stream = SCStream(filter: filter, configuration: configuration, delegate: streamOutput)
                try self.stream?.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: self.videoSampleBufferQueue)
                self.stream?.startCapture()
            } catch {
                logger.error("Failed to start capture: \(error.localizedDescription)")
                continuation.finish(throwing: error)
            }
        }
    }

    /// Stops capturing the screen content.
    func stopCapture() async {
        do {
            try await stream?.stopCapture()
            continuation?.finish()
        } catch {
            logger.error("Failed to stop capture: \(error.localizedDescription)")
            continuation?.finish(throwing: error)
        }
    }

    /// Updates the stream configuration and content filter.
    func update(configuration: SCStreamConfiguration, filter: SCContentFilter) async {
        do {
            try await stream?.updateConfiguration(configuration)
            try await stream?.updateContentFilter(filter)
        } catch {
            logger.error("Failed to update the stream session: \(String(describing: error))")
        }
    }
}

/// A class that handles output from an SCStream, and handles stream errors.
private class CaptureEngineStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    private let logger = Logger(subsystem: "com.example.Overview", category: "CaptureEngineStreamOutput")
    
    var capturedFrameHandler: ((CapturedFrame) -> Void)?
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?

    init(continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?) {
        self.continuation = continuation
    }

    /// Handles the output of a sample buffer from the stream.
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard sampleBuffer.isValid else {
            logger.error("Invalid sample buffer received.")
            return
        }

        switch outputType {
        case .screen:
            if let frame = createFrame(for: sampleBuffer) {
                capturedFrameHandler?(frame)
            }
        case .audio:
            // Handle audio if needed, otherwise log that audio is not implemented
            logger.info("Audio stream received but not processed.")
        default:
            // Convert outputType to a string for logging
            logger.error("Encountered unknown stream output type: \(String(describing: outputType))")
            fatalError("Encountered unknown stream output type: \(outputType)")
        }
    }

    /// Creates a `CapturedFrame` for the video sample buffer.
    private func createFrame(for sampleBuffer: CMSampleBuffer) -> CapturedFrame? {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]] else {
            logger.error("Failed to get sample attachments array.")
            return nil
        }
        
        guard let attachments = attachmentsArray.first else {
            logger.error("Attachments array is empty.")
            return nil
        }
        
        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
            let status = SCFrameStatus(rawValue: statusRawValue), status == .complete else {
            // Silently ignore incomplete frames to avoid log clutter
            return nil
        }
        
        guard let status = SCFrameStatus(rawValue: statusRawValue), status == .complete else {
            logger.error("Frame status is not complete. Status: \(statusRawValue)")
            return nil
        }
        
        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            logger.error("Sample buffer does not contain an image buffer.")
            return nil
        }
        
        guard let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            logger.error("Failed to get IOSurface from pixel buffer.")
            return nil
        }

        let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)

        guard let contentRectDict = attachments[.contentRect] as! CFDictionary? else {
            logger.error("Failed to get contentRect from attachments.")
            return nil
        }

        guard let contentRect = CGRect(dictionaryRepresentation: contentRectDict) else {
            logger.error("Failed to convert contentRect to CGRect.")
            return nil
        }

        guard let contentScale = attachments[.contentScale] as? CGFloat else {
            logger.error("Failed to get contentScale from attachments.")
            return nil
        }

        guard let scaleFactor = attachments[.scaleFactor] as? CGFloat else {
            logger.error("Failed to get scaleFactor from attachments.")
            return nil
        }

        // Successfully created a CapturedFrame
        return CapturedFrame(surface: surface, contentRect: contentRect, contentScale: contentScale, scaleFactor: scaleFactor)
    }


    /// Handles stream stop with an error.
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Stream stopped with error: \(error.localizedDescription)")
        continuation?.finish(throwing: error)
    }
}
