/*
 Capture/CaptureEngine.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages screen capture operations using ScreenCaptureKit, handling frame
 processing, stream management, and error handling for captured content.

 This file includes code derived from Apple Inc.'s ScreenRecorder code sample,
 which is licensed under the MIT License. See LICENSE.md for details.
*/

import ScreenCaptureKit

/// Represents a single captured frame with associated metadata
struct CapturedFrame {
    let contentRect: CGRect
    let contentScale: CGFloat
    let scaleFactor: CGFloat
    let surface: IOSurface?

    static let invalid: CapturedFrame = CapturedFrame(
        contentRect: .zero,
        contentScale: 0,
        scaleFactor: 0,
        surface: nil
    )

    var size: CGSize { contentRect.size }
}

/// Manages the lifecycle and processing of screen capture streams
class CaptureEngine: NSObject, @unchecked Sendable {
    // MARK: - Dependencies
    private let logger = AppLogger.capture
    private let frameProcessingQueue: DispatchQueue = DispatchQueue(
        label: "com.example.apple-samplecode.VideoSampleBufferQueue"
    )

    // MARK: - State Management
    private var frameStreamContinuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?
    private var streamOutput: CaptureEngineStreamOutput?
    private(set) var stream: SCStream?

    // MARK: - Capture Control

    func startCapture(configuration: SCStreamConfiguration, filter: SCContentFilter)
        -> AsyncThrowingStream<CapturedFrame, Error>
    {
        AsyncThrowingStream<CapturedFrame, Error> { continuation in
            logger.debug("Initializing capture stream with filter")

            let streamOutput = CaptureEngineStreamOutput(continuation: continuation)
            self.streamOutput = streamOutput
            streamOutput.capturedFrameHandler = { continuation.yield($0) }

            do {
                self.stream = SCStream(
                    filter: filter,
                    configuration: configuration,
                    delegate: streamOutput
                )

                try self.stream?.addStreamOutput(
                    streamOutput,
                    type: .screen,
                    sampleHandlerQueue: self.frameProcessingQueue
                )
                self.stream?.startCapture()
                logger.info("Capture stream started successfully")
            } catch {
                logger.logError(error, context: "Failed to initialize capture stream")
                continuation.finish(throwing: error)
            }
        }
    }

    func stopCapture() async {
        logger.debug("Initiating capture stream shutdown")

        do {
            try await stream?.stopCapture()
            frameStreamContinuation?.finish()
            logger.info("Capture stream stopped successfully")
        } catch {
            logger.logError(error, context: "Failed to stop capture stream")
            frameStreamContinuation?.finish(throwing: error)
        }
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

/// Handles stream output processing and delegate callbacks
private class CaptureEngineStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    private let logger = AppLogger.capture
    private var frameStreamContinuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?
    var capturedFrameHandler: ((CapturedFrame) -> Void)?

    init(continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?) {
        self.frameStreamContinuation = continuation
        super.init()
        logger.debug("Initialized stream output handler")
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard sampleBuffer.isValid else {
            logger.error("Received invalid sample buffer")
            return
        }

        switch outputType {
        case .screen:
            if let frame: CapturedFrame = extractCapturedFrame(from: sampleBuffer) {
                capturedFrameHandler?(frame)
            }
        case .audio:
            logger.debug("Audio stream output ignored")
        default:
            logger.error("Received unknown output type: \(String(describing: outputType))")
            fatalError("Unknown output type: \(outputType)")
        }
    }

    private func extractCapturedFrame(from sampleBuffer: CMSampleBuffer) -> CapturedFrame? {
        guard
            let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer,
                createIfNecessary: false
            ) as? [[SCStreamFrameInfo: Any]]
        else {
            logger.error("Failed to get sample buffer attachments")
            return nil
        }

        guard let attachments: [SCStreamFrameInfo: Any] = attachmentsArray.first else {
            logger.error("Empty sample buffer attachments")
            return nil
        }

        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
            let status = SCFrameStatus(rawValue: statusRawValue),
            status == .complete
        else {
            return nil
        }

        guard let pixelBuffer: CVImageBuffer = sampleBuffer.imageBuffer else {
            logger.error("Missing image buffer in sample")
            return nil
        }

        guard
            let surfaceRef: IOSurfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?
                .takeUnretainedValue()
        else {
            logger.error("Failed to get IOSurface from buffer")
            return nil
        }

        let surface: IOSurface = unsafeBitCast(surfaceRef, to: IOSurface.self)

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

        return CapturedFrame(
            contentRect: contentRect,
            contentScale: contentScale,
            scaleFactor: scaleFactor,
            surface: surface
        )
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.logError(error, context: "Stream stopped unexpectedly")
        frameStreamContinuation?.finish(throwing: error)
    }
}
