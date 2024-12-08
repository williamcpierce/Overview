/*
 CaptureEngine.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages low-level screen capture operations using ScreenCaptureKit, handling
 frame capture, processing, and delivery to the UI layer with optimized performance.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.

 This file includes code derived from Apple Inc.'s ScreenRecorder code sample,
 which is licensed under the MIT License. See LICENSE.md for details.
*/

import OSLog
import ScreenCaptureKit

/// Encapsulates frame data for efficient display processing
///
/// Key responsibilities:
/// - Maintains IOSurface reference for hardware-accelerated rendering
/// - Manages scaling factors for proper display density
/// - Provides geometry information for layout calculations
///
/// Coordinates with:
/// - CaptureEngine: Source of captured frame data
/// - Capture: Consumer for frame rendering
/// - PreviewView: Handler for display sizing
struct CapturedFrame {
    /// Represents invalid capture state
    /// - Note: Used for initialization and error conditions
    static let invalid = CapturedFrame(
        surface: nil, contentRect: .zero, contentScale: 0, scaleFactor: 0)

    /// Raw pixel buffer for rendering
    /// - Note: May be nil if capture fails
    let surface: IOSurface?

    /// Frame bounds in screen coordinates
    let contentRect: CGRect

    /// Display scale for Retina rendering
    let contentScale: CGFloat

    /// Window scale for proper sizing
    let scaleFactor: CGFloat

    /// Convenience accessor for dimensions
    var size: CGSize { contentRect.size }
}

/// Controls screen capture configuration and frame processing
///
/// Key responsibilities:
/// - Manages SCStream lifecycle and configuration
/// - Processes captured frames into displayable format
/// - Delivers frames through async stream interface
/// - Handles capture errors and state transitions
///
/// Coordinates with:
/// - CaptureManager: High-level capture coordination
/// - StreamConfigurationService: Stream setup
/// - WindowAccessor: Display scaling
/// - PreviewView: Frame consumption
class CaptureEngine: NSObject, @unchecked Sendable {
    // MARK: - Properties

    /// System logger for capture events
    private let logger = Logger()

    /// Active capture stream
    /// - Note: Nil when capture is inactive
    private(set) var stream: SCStream?

    /// Handles stream output processing
    private var streamOutput: CaptureEngineStreamOutput?

    /// Dedicated queue for frame processing
    /// - Important: Separate queue prevents frame drops
    private let videoSampleBufferQueue = DispatchQueue(
        label: "com.example.apple-samplecode.VideoSampleBufferQueue")

    /// Frame delivery continuation
    /// - Warning: Must be updated on videoSampleBufferQueue
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?

    // MARK: - Public Methods

    /// Begins screen content capture
    ///
    /// Flow:
    /// 1. Creates frame delivery stream
    /// 2. Configures stream output
    /// 3. Initializes capture stream
    /// 4. Begins frame processing
    ///
    /// - Parameters:
    ///   - configuration: Stream quality settings
    ///   - filter: Content filter for capture source
    ///
    /// - Returns: AsyncThrowingStream of CapturedFrames
    /// - Throws: Stream configuration errors
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

    /// Stops active capture
    ///
    /// Flow:
    /// 1. Stops SCStream if active
    /// 2. Finishes frame delivery
    /// 3. Cleans up resources
    ///
    /// - Warning: Must be called before release
    func stopCapture() async {
        do {
            try await stream?.stopCapture()
            continuation?.finish()
        } catch {
            logger.error("Failed to stop capture: \(error.localizedDescription)")
            continuation?.finish(throwing: error)
        }
    }

    /// Updates stream configuration
    ///
    /// Flow:
    /// 1. Updates stream settings
    /// 2. Updates content filter
    /// 3. Maintains capture
    ///
    /// - Parameters:
    ///   - configuration: New stream settings
    ///   - filter: New content filter
    ///
    /// - Important: Updates without stopping stream
    /// - Warning: May cause frame drops
    func update(configuration: SCStreamConfiguration, filter: SCContentFilter) async {
        do {
            try await stream?.updateConfiguration(configuration)
            try await stream?.updateContentFilter(filter)
        } catch {
            logger.error("Failed to update stream: \(String(describing: error))")
        }
    }
}

/// Processes SCStream output and manages errors
///
/// Key responsibilities:
/// - Converts raw frames to CapturedFrame format
/// - Handles stream delegate callbacks
/// - Manages frame delivery continuation
///
/// Coordinates with:
/// - CaptureEngine: Frame delivery
/// - SCStream: Raw capture data
private class CaptureEngineStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    // MARK: - Properties

    /// System logger for processing events
    private let logger = Logger(
        subsystem: "com.example.Overview",
        category: "CaptureEngineStreamOutput"
    )

    /// Frame delivery callback
    var capturedFrameHandler: ((CapturedFrame) -> Void)?

    /// Stream continuation for async delivery
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?

    // MARK: - Initialization

    /// Creates output processor
    /// - Parameter continuation: Frame delivery continuation
    init(continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?) {
        self.continuation = continuation
    }

    // MARK: - SCStreamOutput Methods

    /// Processes incoming frame data
    ///
    /// Flow:
    /// 1. Validates sample buffer
    /// 2. Processes by output type
    /// 3. Creates CapturedFrame
    ///
    /// - Parameters:
    ///   - stream: Source stream
    ///   - sampleBuffer: Raw frame data
    ///   - outputType: Stream output type
    ///
    /// - Note: Called on videoSampleBufferQueue
    func stream(
        _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard sampleBuffer.isValid else {
            logger.error("Invalid sample buffer")
            return
        }

        switch outputType {
        case .screen:
            if let frame = createFrame(for: sampleBuffer) {
                capturedFrameHandler?(frame)
            }
        case .audio:
            logger.info("Audio stream ignored")
        default:
            logger.error("Unknown output type: \(String(describing: outputType))")
            fatalError("Unknown output type: \(outputType)")
        }
    }

    // MARK: - Private Methods

    /// Creates CapturedFrame from sample buffer
    ///
    /// Flow:
    /// 1. Extracts frame metadata
    /// 2. Processes pixel buffer
    /// 3. Constructs frame object
    ///
    /// - Parameter sampleBuffer: Raw frame data
    /// - Returns: CapturedFrame if successful
    private func createFrame(for sampleBuffer: CMSampleBuffer) -> CapturedFrame? {
        guard
            let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]]
        else {
            logger.error("Failed to get attachments")
            return nil
        }

        guard let attachments = attachmentsArray.first else {
            logger.error("Empty attachments")
            return nil
        }

        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
            let status = SCFrameStatus(rawValue: statusRawValue),
            status == .complete
        else {
            return nil
        }

        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            logger.error("No image buffer")
            return nil
        }

        guard let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            logger.error("Failed to get IOSurface")
            return nil
        }

        let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)

        guard let contentRectDict = attachments[.contentRect] as! CFDictionary? else {
            logger.error("Failed to get contentRect")
            return nil
        }

        guard let contentRect = CGRect(dictionaryRepresentation: contentRectDict) else {
            logger.error("Failed to convert contentRect")
            return nil
        }

        guard let contentScale = attachments[.contentScale] as? CGFloat else {
            logger.error("Failed to get contentScale")
            return nil
        }

        guard let scaleFactor = attachments[.scaleFactor] as? CGFloat else {
            logger.error("Failed to get scaleFactor")
            return nil
        }

        return CapturedFrame(
            surface: surface,
            contentRect: contentRect,
            contentScale: contentScale,
            scaleFactor: scaleFactor
        )
    }

    // MARK: - SCStreamDelegate Methods

    /// Handles stream errors
    ///
    /// - Parameters:
    ///   - stream: Failed stream
    ///   - error: Stream error
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Stream error: \(error.localizedDescription)")
        continuation?.finish(throwing: error)
    }
}
