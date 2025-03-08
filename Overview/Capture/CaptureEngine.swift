/*
 Capture/CaptureEngine.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages screen capture operations using ScreenCaptureKit, handling frame
 processing, stream management, and error handling for captured content.

 This file includes code derived from Apple Inc.'s CapturingScreenContentInMacOS
 code sample, which is licensed under the MIT License. See LICENSE.md for details.
*/

import ScreenCaptureKit

class CaptureEngine: NSObject, @unchecked Sendable {
    // Dependencies
    private let logger = AppLogger.capture

    // Private State
    private let frameProcessingQueue = DispatchQueue(
        label: "io.williampierce.Overview.VideoSampleBufferQueue"
    )
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?
    private var streamOutput: CaptureEngineStreamOutput?
    private(set) var stream: SCStream?

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
            if let stream = stream {
                try await stream.stopCapture()
                logger.info("Capture stream stopped successfully")
            }
            continuation?.finish()
        } catch {
            logger.logError(error, context: "Failed to stop capture stream")
            continuation?.finish(throwing: error)
        }

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
    // Dependencies
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?
    private let logger = AppLogger.capture

    // Public Properties
    var capturedFrameHandler: ((CapturedFrame) -> Void)?

    init(continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?) {
        self.continuation = continuation
        logger.debug("Initialized stream output handler")
    }

    // MARK: - Stream Output Handling

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard sampleBuffer.isValid else {
            logger.error("Received invalid sample buffer")
            return
        }

        if outputType == .screen, let frame = createFrame(for: sampleBuffer) {
            capturedFrameHandler?(frame)
        }
    }

    // MARK: - Frame Processing

    private func createFrame(for sampleBuffer: CMSampleBuffer) -> CapturedFrame? {
        guard
            let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer,
                createIfNecessary: false
            ) as? [[SCStreamFrameInfo: Any]],
            let attachments = attachmentsArray.first
        else {
            logger.error("Failed to get sample buffer attachments")
            return nil
        }

        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
            let status = SCFrameStatus(rawValue: statusRawValue),
            status == .complete
        else {
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

        guard let contentRectDict = attachments[.contentRect],
            let contentRect = CGRect(dictionaryRepresentation: contentRectDict as! CFDictionary),
            let contentScale = attachments[.contentScale] as? CGFloat,
            let scaleFactor = attachments[.scaleFactor] as? CGFloat
        else {
            logger.error("Failed to get frame metadata from attachments")
            return nil
        }

        return CapturedFrame(
            contentRect: contentRect,
            contentScale: contentScale,
            scaleFactor: scaleFactor,
            surface: surface
        )
    }

    // MARK: - Error Handling

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.logError(error, context: "Stream stopped with error")
        continuation?.finish(throwing: error)
    }
}

// MARK: - Support Types

struct CapturedFrame {
    let contentRect: CGRect
    let contentScale: CGFloat
    let scaleFactor: CGFloat
    let surface: IOSurface?

    static let invalid = CapturedFrame(
        contentRect: .zero,
        contentScale: 0,
        scaleFactor: 0,
        surface: nil
    )

    var size: CGSize { contentRect.size }
}
