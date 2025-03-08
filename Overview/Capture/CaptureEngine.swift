/*
 Capture/CaptureEngine.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages screen capture operations using ScreenCaptureKit, handling frame
 processing, stream management, and error handling for captured content.

 This file includes code derived from Apple Inc.'s ScreenRecorder code sample,
 which is licensed under the MIT License. See LICENSE.md for details.
*/

import AVFAudio
import Combine
import ScreenCaptureKit

/// A structure that contains the video data to render.
struct CapturedFrame {
    static let invalid = CapturedFrame(
        surface: nil,
        contentRect: .zero,
        contentScale: 0,
        scaleFactor: 0
    )

    let surface: IOSurface?
    let contentRect: CGRect
    let contentScale: CGFloat
    let scaleFactor: CGFloat

    var size: CGSize { contentRect.size }
}

/// An object that captures a stream of captured sample buffers containing screen content.
class CaptureEngine: NSObject, @unchecked Sendable {
    // Dependencies
    private let logger = AppLogger.capture

    // Stream state
    private(set) var stream: SCStream?
    private var streamOutput: CaptureEngineStreamOutput?
    private let frameProcessingQueue = DispatchQueue(
        label: "io.williampierce.Overview.VideoSampleBufferQueue"
    )
    private let audioSampleBufferQueue = DispatchQueue(
        label: "io.williampierce.Overview.AudioSampleBufferQueue"
    )
    private let micSampleBufferQueue = DispatchQueue(
        label: "io.williampierce.Overview.MicSampleBufferQueue"
    )

    // Continuation management
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?

    // MARK: - Stream Control

    func startCapture(configuration: SCStreamConfiguration, filter: SCContentFilter)
        -> AsyncThrowingStream<CapturedFrame, Error>
    {
        AsyncThrowingStream<CapturedFrame, Error> { continuation in
            logger.debug("Initializing capture stream with filter")
            self.continuation = continuation

            let streamOutput = CaptureEngineStreamOutput(continuation: continuation)
            self.streamOutput = streamOutput

            streamOutput.capturedFrameHandler = { continuation.yield($0) }

            do {
                // Create the stream with the provided filter and configuration
                self.stream = SCStream(
                    filter: filter,
                    configuration: configuration,
                    delegate: streamOutput
                )

                // Add a stream output to capture screen content
                try self.stream?.addStreamOutput(
                    streamOutput,
                    type: .screen,
                    sampleHandlerQueue: frameProcessingQueue
                )

                // Add a stream output to capture audio
                try self.stream?.addStreamOutput(
                    streamOutput,
                    type: .audio,
                    sampleHandlerQueue: audioSampleBufferQueue
                )

                // Start capturing
                try self.stream?.startCapture()
                logger.info("Capture stream started successfully")
            } catch {
                logger.logError(error, context: "Failed to initialize capture stream")
                continuation.finish(throwing: error)

                // Clean up resources on error
                self.stream = nil
                self.streamOutput = nil
                self.continuation = nil
            }
        }
    }

    func stopCapture() async {
        logger.debug("Initiating capture stream shutdown")

        do {
            if let stream = stream {
                try await stream.stopCapture()
                logger.info("Capture stream stopped successfully")
            }
        } catch {
            logger.logError(error, context: "Failed to stop capture stream")
        }

        // Clean up resources regardless of any errors
        continuation?.finish()
        stream = nil
        streamOutput = nil
        continuation = nil
    }

    func update(configuration: SCStreamConfiguration, filter: SCContentFilter) async {
        logger.debug("Updating capture configuration")

        do {
            try await stream?.updateConfiguration(configuration)
            try await stream?.updateContentFilter(filter)
            logger.info("Stream configuration updated successfully")
        } catch {
            logger.logError(error, context: "Failed to update stream configuration")
        }
    }
}

// MARK: - Stream Output

private class CaptureEngineStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    // Actions
    var capturedFrameHandler: ((CapturedFrame) -> Void)?

    // Continuation management
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?
    private let logger = AppLogger.capture

    init(continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?) {
        self.continuation = continuation
        super.init()
        logger.debug("Initialized stream output handler")
    }

    // MARK: - SCStreamOutput

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        // Return early if the sample buffer is invalid.
        guard sampleBuffer.isValid else { return }

        // Process only screen frames
        if outputType == .screen, let frame = createFrame(for: sampleBuffer) {
            capturedFrameHandler?(frame)
        }
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.logError(error, context: "Stream stopped with error")
        continuation?.finish(throwing: error)
    }

    // MARK: - Frame Processing

    private func createFrame(for sampleBuffer: CMSampleBuffer) -> CapturedFrame? {
        // Retrieve the array of metadata attachments from the sample buffer.
        guard
            let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
            let attachments = attachmentsArray.first
        else {
            logger.error("Failed to get sample buffer attachments")
            return nil
        }

        // Validate the status of the frame. If it isn't .complete, return nil.
        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
            let status = SCFrameStatus(rawValue: statusRawValue),
            status == .complete
        else {
            return nil
        }

        // Get the pixel buffer that contains the image data.
        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            logger.error("Missing image buffer in sample")
            return nil
        }

        // Get the backing IOSurface.
        guard let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            logger.error("Failed to get IOSurface from buffer")
            return nil
        }
        let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)

        // Retrieve the content rectangle, scale, and scale factor.
        guard let contentRectDict = attachments[.contentRect],
            let contentRect = CGRect(dictionaryRepresentation: contentRectDict as! CFDictionary),
            let contentScale = attachments[.contentScale] as? CGFloat,
            let scaleFactor = attachments[.scaleFactor] as? CGFloat
        else {
            logger.error("Failed to get frame metadata from attachments")
            return nil
        }

        // Create a new frame with the relevant data.
        return CapturedFrame(
            surface: surface,
            contentRect: contentRect,
            contentScale: contentScale,
            scaleFactor: scaleFactor
        )
    }
}

// MARK: - CMSampleBuffer Extension

extension CMSampleBuffer {
    var imageBuffer: CVImageBuffer? {
        CMSampleBufferGetImageBuffer(self)
    }
}
