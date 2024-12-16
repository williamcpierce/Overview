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

import ScreenCaptureKit

/// Encapsulates frame data for efficient display processing using hardware acceleration
///
/// Key responsibilities:
/// - Maintains IOSurface reference for hardware-accelerated rendering
/// - Manages scaling factors for proper display density
/// - Provides geometry information for layout calculations
/// - Ensures safe resource management of system surfaces
///
/// Coordinates with:
/// - CaptureEngine: Source of captured frame data and lifecycle
/// - Capture: Consumer for frame rendering and display
/// - PreviewView: Handler for display sizing and layout
/// - PreviewAccessor: Coordinates preview scaling with window properties
struct CapturedFrame {
    /// Represents invalid capture state for initialization and error handling
    /// - Note: Used when capture fails or during state transitions
    static let invalid = CapturedFrame(
        surface: nil, contentRect: .zero, contentScale: 0, scaleFactor: 0)

    /// Raw pixel buffer for hardware-accelerated rendering
    /// - Note: May be nil if capture fails or during initialization
    let surface: IOSurface?

    /// Frame bounds in screen coordinates for proper positioning
    let contentRect: CGRect

    /// Display scale factor for Retina rendering quality
    let contentScale: CGFloat

    /// Window scale for maintaining proper dimensions
    let scaleFactor: CGFloat

    /// Convenience accessor for frame dimensions
    var size: CGSize { contentRect.size }
}

/// Controls screen capture configuration and frame processing with optimized performance
///
/// Key responsibilities:
/// - Manages SCStream lifecycle and configuration updates
/// - Processes captured frames into displayable format
/// - Delivers frames through async stream interface
/// - Handles capture errors and state transitions
/// - Ensures proper resource cleanup
///
/// Coordinates with:
/// - CaptureManager: High-level capture coordination and state
/// - StreamConfigurationService: Stream setup and updates
/// - PreviewAccessor: Display scaling and dimensions
/// - PreviewView: Frame consumption and display
class CaptureEngine: NSObject, @unchecked Sendable {
    // MARK: - Properties

    /// System logger for capture events and error tracking
    private let logger = AppLogger.capture

    /// Active capture stream for window content
    /// - Note: Nil when capture is inactive or during initialization
    private(set) var stream: SCStream?

    /// Handles stream output processing and frame conversion
    private var streamOutput: CaptureEngineStreamOutput?

    /// Dedicated queue for frame processing to prevent frame drops
    /// - Note: Separate queue ensures smooth capture performance
    private let videoSampleBufferQueue = DispatchQueue(
        label: "com.example.apple-samplecode.VideoSampleBufferQueue")

    /// Frame delivery continuation for async stream interface
    /// - Warning: Must only be updated on videoSampleBufferQueue
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?

    // MARK: - Public Methods

    /// Begins screen content capture with specified configuration
    ///
    /// Flow:
    /// 1. Creates frame delivery stream for async interface
    /// 2. Configures stream output processor
    /// 3. Initializes capture stream with settings
    /// 4. Begins frame processing and delivery
    ///
    /// - Parameters:
    ///   - configuration: Stream quality and performance settings
    ///   - filter: Content filter defining capture source
    ///
    /// - Returns: AsyncThrowingStream of processed CapturedFrames
    /// - Throws: Stream configuration and initialization errors
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
    /// 1. Stops SCStream if currently active
    /// 2. Finishes frame delivery stream
    /// 3. Cleans up capture resources
    /// 4. Handles cleanup errors gracefully
    ///
    /// - Important: Must be called before release to prevent leaks
    func stopCapture() async {
        logger.debug("Stopping capture stream")

        do {
            try await stream?.stopCapture()
            continuation?.finish()
            logger.info("Capture stream stopped successfully")
        } catch {
            logger.error("Failed to stop capture: \(error.localizedDescription)")
            continuation?.finish(throwing: error)
        }
    }

    /// Updates stream configuration during active capture
    ///
    /// Flow:
    /// 1. Updates stream quality settings
    /// 2. Updates content filter bounds
    /// 3. Maintains active capture state
    /// 4. Handles update errors gracefully
    ///
    /// - Parameters:
    ///   - configuration: New stream quality settings
    ///   - filter: New content filter bounds
    ///
    /// - Important: Updates without stopping active capture
    /// - Warning: May cause momentary frame drops during transition
    func update(configuration: SCStreamConfiguration, filter: SCContentFilter) async {
        logger.debug("Updating capture configuration")

        do {
            try await stream?.updateConfiguration(configuration)
            try await stream?.updateContentFilter(filter)
            logger.info("Stream configuration updated successfully")
        } catch {
            logger.error("Failed to update stream: \(error.localizedDescription)")
        }
    }
}

/// Processes SCStream output and manages error conditions
///
/// Key responsibilities:
/// - Converts raw frame data to CapturedFrame format
/// - Handles stream delegate callbacks and errors
/// - Manages frame delivery continuation
/// - Ensures proper error propagation
///
/// Coordinates with:
/// - CaptureEngine: Frame delivery and state
/// - SCStream: Raw capture data processing
/// - PreviewView: Frame consumption
private class CaptureEngineStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    // MARK: - Properties

    /// System logger for processing events
    private let logger = AppLogger.capture

    /// Frame delivery callback for UI updates
    var capturedFrameHandler: ((CapturedFrame) -> Void)?

    /// Stream continuation for async delivery
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?

    // MARK: - Initialization

    /// Creates output processor with continuation
    /// - Parameter continuation: Frame delivery continuation
    init(continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?) {
        self.continuation = continuation
    }

    // MARK: - SCStreamOutput Methods

    /// Processes incoming frame data for display
    ///
    /// Flow:
    /// 1. Validates sample buffer integrity
    /// 2. Routes processing by output type
    /// 3. Creates CapturedFrame for display
    /// 4. Delivers frame through handler
    ///
    /// - Parameters:
    ///   - stream: Source stream reference
    ///   - sampleBuffer: Raw frame buffer data
    ///   - outputType: Stream output classification
    ///
    /// - Note: Called on videoSampleBufferQueue
    func stream(
        _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard sampleBuffer.isValid else {
            logger.error("Received invalid sample buffer")
            return
        }

        switch outputType {
        case .screen:
            if let frame = createFrame(for: sampleBuffer) {
                capturedFrameHandler?(frame)
            }
        case .audio:
            logger.debug("Audio stream output ignored")
        default:
            logger.error("Unknown output type: \(String(describing: outputType))")
            fatalError("Unknown output type: \(outputType)")
        }
    }

    // MARK: - Private Methods

    /// Creates CapturedFrame from raw sample buffer
    ///
    /// Flow:
    /// 1. Extracts frame metadata and properties
    /// 2. Processes pixel buffer into IOSurface
    /// 3. Constructs frame with scaling info
    /// 4. Handles conversion failures gracefully
    ///
    /// - Parameter sampleBuffer: Raw frame buffer data
    /// - Returns: CapturedFrame if conversion succeeds
    private func createFrame(for sampleBuffer: CMSampleBuffer) -> CapturedFrame? {
        guard
            let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]]
        else {
            logger.error("Failed to get sample buffer attachments")
            return nil
        }

        guard let attachments = attachmentsArray.first else {
            logger.error("Empty sample buffer attachments")
            return nil
        }

        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
            let status = SCFrameStatus(rawValue: statusRawValue),
            status == .complete
        else {
            logger.debug("Incomplete frame status")
            return nil
        }

        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            logger.error("Missing image buffer in sample")
            return nil
        }

        guard let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            logger.error("Failed to get IOSurface from buffer")
            return nil
        }

        let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)

        guard let contentRectDict = attachments[.contentRect] as! CFDictionary? else {
            logger.error("Missing content rect in attachments")
            return nil
        }

        guard let contentRect = CGRect(dictionaryRepresentation: contentRectDict) else {
            logger.error("Failed to convert content rect dictionary")
            return nil
        }

        guard let contentScale = attachments[.contentScale] as? CGFloat else {
            logger.error("Missing content scale in attachments")
            return nil
        }

        guard let scaleFactor = attachments[.scaleFactor] as? CGFloat else {
            logger.error("Missing scale factor in attachments")
            return nil
        }

        logger.debug("Created frame: size=\(contentRect.size), scale=\(contentScale)")
        return CapturedFrame(
            surface: surface,
            contentRect: contentRect,
            contentScale: contentScale,
            scaleFactor: scaleFactor
        )
    }

    // MARK: - SCStreamDelegate Methods

    /// Handles stream errors and completion
    ///
    /// - Parameters:
    ///   - stream: Failed stream reference
    ///   - error: Stream error description
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Stream stopped with error: \(error.localizedDescription)")
        continuation?.finish(throwing: error)
    }
}
