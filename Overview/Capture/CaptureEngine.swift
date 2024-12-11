/*
 CaptureEngine.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.

 This file includes code derived from Apple Inc.'s ScreenRecorder code sample,
 which is licensed under the MIT License. See LICENSE.md for details.
*/

import OSLog
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

class CaptureEngine: NSObject, @unchecked Sendable {
    private let logger = Logger()
    private(set) var stream: SCStream?
    private var streamOutput: CaptureEngineStreamOutput?
    private let videoSampleBufferQueue = DispatchQueue(
        label: "com.example.apple-samplecode.VideoSampleBufferQueue")
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?

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

    func stopCapture() async {
        do {
            try await stream?.stopCapture()
            continuation?.finish()
        } catch {
            logger.error("Failed to stop capture: \(error.localizedDescription)")
            continuation?.finish(throwing: error)
        }
    }

    func update(configuration: SCStreamConfiguration, filter: SCContentFilter) async {
        do {
            try await stream?.updateConfiguration(configuration)
            try await stream?.updateContentFilter(filter)
        } catch {
            logger.error("Failed to update stream: \(String(describing: error))")
        }
    }
}

private class CaptureEngineStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    private let logger = Logger(
        subsystem: "com.example.Overview",
        category: "CaptureEngineStreamOutput"
    )
    var capturedFrameHandler: ((CapturedFrame) -> Void)?
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?
    init(continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?) {
        self.continuation = continuation
    }

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

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Stream error: \(error.localizedDescription)")
        continuation?.finish(throwing: error)
    }
}
