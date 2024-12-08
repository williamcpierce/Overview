/*
 CaptureEngine.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file includes code derived from Apple Inc.'s ScreenRecorder code sample,
 which is licensed under the MIT License. See LICENSE.md for details.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file in the root of this project.
*/

import OSLog
import ScreenCaptureKit

/// Encapsulates captured frame data for efficient display and processing
///
/// Key responsibilities:
/// - Holds IOSurface data and metadata for frame rendering
/// - Maintains scaling and content rect information
/// - Provides a static invalid state for error handling
struct CapturedFrame {
    /// Represents an invalid frame state for error conditions and initialization
    static let invalid = CapturedFrame(
        surface: nil, contentRect: .zero, contentScale: 0, scaleFactor: 0)

    let surface: IOSurface?
    let contentRect: CGRect
    let contentScale: CGFloat
    let scaleFactor: CGFloat

    var size: CGSize { contentRect.size }
}

/// Manages screen capture stream configuration and frame delivery
///
/// Key responsibilities:
/// - Configures and manages SCStream lifecycle
/// - Delivers captured frames via async stream
/// - Handles stream errors and state changes
///
/// Coordinates with:
/// - CaptureManager: For high-level capture session management
/// - Capture: For frame rendering in SwiftUI
class CaptureEngine: NSObject, @unchecked Sendable {
    // MARK: - Properties

    private let logger = Logger()
    private(set) var stream: SCStream?
    private var streamOutput: CaptureEngineStreamOutput?

    /// Dedicated queue for video sample processing to prevent frame drops
    private let videoSampleBufferQueue = DispatchQueue(
        label: "com.example.apple-samplecode.VideoSampleBufferQueue")

    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?

    // MARK: - Public Methods

    /// Initiates screen content capture with specified configuration
    ///
    /// Flow:
    /// 1. Creates async stream for frame delivery
    /// 2. Configures stream output and handlers
    /// 3. Initializes and starts SCStream
    ///
    /// - Throws: Stream configuration and startup errors
    func startCapture(configuration: SCStreamConfiguration, filter: SCContentFilter)
        -> AsyncThrowingStream<CapturedFrame, Error>
    {
        AsyncThrowingStream<CapturedFrame, Error> { continuation in
            let streamOutput = CaptureEngineStreamOutput(continuation: continuation)
            self.streamOutput = streamOutput
            streamOutput.capturedFrameHandler = { continuation.yield($0) }

            do {
                self.stream = SCStream(
                    filter: filter, configuration: configuration, delegate: streamOutput)
                try self.stream?.addStreamOutput(
                    streamOutput, type: .screen, sampleHandlerQueue: self.videoSampleBufferQueue)
                self.stream?.startCapture()
            } catch {
                logger.error("Failed to start capture: \(error.localizedDescription)")
                continuation.finish(throwing: error)
            }
        }
    }

    /// Stops active capture and cleans up resources
    ///
    /// Flow:
    /// 1. Stops SCStream capture
    /// 2. Finishes frame delivery continuation
    func stopCapture() async {
        do {
            try await stream?.stopCapture()
            continuation?.finish()
        } catch {
            logger.error("Failed to stop capture: \(error.localizedDescription)")
            continuation?.finish(throwing: error)
        }
    }

    /// Updates stream configuration while maintaining capture
    ///
    /// - Important: Updates are applied without stopping the stream
    func update(configuration: SCStreamConfiguration, filter: SCContentFilter) async {
        do {
            try await stream?.updateConfiguration(configuration)
            try await stream?.updateContentFilter(filter)
        } catch {
            logger.error("Failed to update the stream session: \(String(describing: error))")
        }
    }
}

/// Handles SCStream output processing and error management
///
/// Key responsibilities:
/// - Processes raw frame data into CapturedFrame instances
/// - Manages stream delegate callbacks
/// - Provides error handling and logging
private class CaptureEngineStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    // MARK: - Properties

    private let logger = Logger(
        subsystem: "com.example.Overview", category: "CaptureEngineStreamOutput")

    var capturedFrameHandler: ((CapturedFrame) -> Void)?
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?

    // MARK: - Initialization

    init(continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?) {
        self.continuation = continuation
    }

    // MARK: - SCStreamOutput Methods

    /// Processes incoming sample buffers and converts to CapturedFrames
    ///
    /// Flow:
    /// 1. Validates sample buffer
    /// 2. Processes based on output type
    /// 3. Creates and delivers CapturedFrame for screen content
    func stream(
        _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
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
            /// Audio processing not implemented in current version
            logger.info("Audio stream received but not processed.")
        default:
            /// Unexpected output type - should never occur with current configuration
            logger.error(
                "Encountered unknown stream output type: \(String(describing: outputType))")
            fatalError("Encountered unknown stream output type: \(outputType)")
        }
    }

    /// Converts CMSampleBuffer to CapturedFrame for rendering
    ///
    /// Flow:
    /// 1. Extracts frame metadata and status
    /// 2. Processes pixel buffer into IOSurface
    /// 3. Constructs CapturedFrame with scaling info
    ///
    /// - Returns: nil if conversion fails at any stage
    private func createFrame(for sampleBuffer: CMSampleBuffer) -> CapturedFrame? {
        /// Extract frame attachments
        guard
            let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]]
        else {
            logger.error("Failed to get sample attachments array.")
            return nil
        }

        guard let attachments = attachmentsArray.first else {
            logger.error("Attachments array is empty.")
            return nil
        }

        /// Validate frame completion status
        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
            let status = SCFrameStatus(rawValue: statusRawValue), status == .complete
        else {
            /// Skip incomplete frames without logging to reduce noise
            return nil
        }

        guard let status = SCFrameStatus(rawValue: statusRawValue), status == .complete else {
            logger.error("Frame status is not complete. Status: \(statusRawValue)")
            return nil
        }

        /// Extract pixel buffer and convert to IOSurface
        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            logger.error("Sample buffer does not contain an image buffer.")
            return nil
        }

        guard let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            logger.error("Failed to get IOSurface from pixel buffer.")
            return nil
        }

        let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)

        /// Extract frame geometry and scaling information
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

        return CapturedFrame(
            surface: surface, contentRect: contentRect, contentScale: contentScale,
            scaleFactor: scaleFactor)
    }

    // MARK: - SCStreamDelegate Methods

    /// Handles stream errors by finishing the continuation with error
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Stream stopped with error: \(error.localizedDescription)")
        continuation?.finish(throwing: error)
    }
}
