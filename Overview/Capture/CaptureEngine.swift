/*
 CaptureEngine.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages low-level screen capture operations using ScreenCaptureKit, handling
 frame capture, processing, and delivery to the UI layer with optimized performance.

 This file includes code derived from Apple Inc.'s ScreenRecorder code sample,
 which is licensed under the MIT License. See LICENSE.md for details.
*/

import ScreenCaptureKit

struct CapturedFrame {
    static let invalid = CapturedFrame(
        surface: nil, contentRect: .zero, contentScale: 0, scaleFactor: 0)

    let surface: IOSurface?
    let contentRect: CGRect
    let contentScale: CGFloat
    let scaleFactor: CGFloat
    var size: CGSize { contentRect.size }
}

/// Coordinates hardware-accelerated window capture and frame delivery using ScreenCaptureKit
class CaptureEngine: NSObject, @unchecked Sendable {
    private let logger = AppLogger.capture
    private(set) var stream: SCStream?
    private var streamOutput: CaptureEngineStreamOutput?
    private let frameProcessingQueue = DispatchQueue(
        label: "com.example.apple-samplecode.VideoSampleBufferQueue")
    private var frameStreamContinuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?

    /// Initiates window capture with the specified quality settings and content bounds
    /// - Returns: An async stream of hardware-accelerated capture frames
    /// - Throws: Configuration or initialization errors that prevent capture
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
                    streamOutput, type: .screen, sampleHandlerQueue: self.frameProcessingQueue)
                self.stream?.startCapture()
            } catch {
                logger.error("Failed to start capture: \(error.localizedDescription)")
                continuation.finish(throwing: error)
            }
        }
    }

    /// Gracefully terminates active capture and releases resources
    func stopCapture() async {
        logger.debug("Stopping capture stream")

        do {
            try await stream?.stopCapture()
            frameStreamContinuation?.finish()
            logger.info("Capture stream stopped successfully")
        } catch {
            logger.error("Failed to stop capture: \(error.localizedDescription)")
            frameStreamContinuation?.finish(throwing: error)
        }
    }

    /// Modifies capture parameters without interrupting the active stream
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

private class CaptureEngineStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    private let logger = AppLogger.capture
    var capturedFrameHandler: ((CapturedFrame) -> Void)?
    private var frameStreamContinuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?

    init(continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?) {
        self.frameStreamContinuation = continuation
    }

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
            if let frame = extractCapturedFrame(from: sampleBuffer) {
                capturedFrameHandler?(frame)
            }
        case .audio:
            logger.debug("Audio stream output ignored")
        default:
            logger.error("Unknown output type: \(String(describing: outputType))")
            fatalError("Unknown output type: \(outputType)")
        }
    }

    private func extractCapturedFrame(from sampleBuffer: CMSampleBuffer) -> CapturedFrame? {
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

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Stream stopped with error: \(error.localizedDescription)")
        frameStreamContinuation?.finish(throwing: error)
    }
}
