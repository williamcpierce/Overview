/*
 Capture/CaptureEngine.swift
 Overview Dev

 ScreenCaptureKit adapter. Frame extraction derives from Apple's MIT-licensed sample.
 All stream mutations pass through one serial queue; callbacks only yield immutable frames.
*/
import ScreenCaptureKit

struct CaptureRequest {
    let source: SCWindow
    let frameRate: Double
    let pixelSize: CGSize
}

@MainActor
final class CaptureEngine: CaptureSession {
    typealias Request = CaptureRequest
    typealias Frame = CapturedFrame
    private let operations = SessionOperationQueue()
    private let frameQueue = DispatchQueue(label: "local.chriswilliamson.OverviewDev.frames")
    private var stream: SCStream?
    private var output: CaptureOutput?
    private let configuration = CaptureConfigurationService()

    func start(_ request: CaptureRequest) async throws -> AsyncThrowingStream<SessionEvent<CapturedFrame>, Error> {
        try await operations.perform { [self] in
            let (config, filter) = configuration.createConfiguration(request.source, frameRate: request.frameRate, pixelSize: request.pixelSize)
            let pair = AsyncThrowingStream<SessionEvent<CapturedFrame>, Error>.makeStream(bufferingPolicy: .bufferingNewest(1))
            let output = CaptureOutput(continuation: pair.continuation)
            let stream = SCStream(filter: filter, configuration: config, delegate: output)
            self.stream = stream
            self.output = output
            do {
                try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: frameQueue)
                try await stream.startCapture()
                guard stream.isCapturing else { throw CaptureAdapterError.notCapturing }
                return pair.stream
            } catch {
                pair.continuation.finish(throwing: error)
                try? await stream.stopCapture()
                self.stream = nil
                self.output = nil
                throw error
            }
        }
    }

    func stop() async {
        _ = try? await operations.perform { [self] in
            if let stream { try? await stream.stopCapture() }
            output?.finish()
            stream = nil
            output = nil
        }
    }

    func update(_ request: CaptureRequest) async throws {
        try await operations.perform { [self] in
            guard let stream else { return }
            let (config, filter) = configuration.createConfiguration(request.source, frameRate: request.frameRate, pixelSize: request.pixelSize)
            try await stream.updateContentFilter(filter)
            try await stream.updateConfiguration(config)
        }
    }
}

private enum CaptureAdapterError: Error { case notCapturing }

private final class CaptureOutput: NSObject, SCStreamOutput, SCStreamDelegate, Sendable {
    private let continuation: AsyncThrowingStream<SessionEvent<CapturedFrame>, Error>.Continuation
    init(continuation: AsyncThrowingStream<SessionEvent<CapturedFrame>, Error>.Continuation) {
        self.continuation = continuation
    }
    func finish() { continuation.finish() }
    func stream(_ stream: SCStream, didStopWithError error: Error) { continuation.finish(throwing: error) }
    func streamDidBecomeActive(_ stream: SCStream) { continuation.yield(.active) }
    func streamDidBecomeInactive(_ stream: SCStream) { continuation.yield(.inactive) }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let metadata = attachments.first,
              let raw = metadata[.status] as? Int,
              SCFrameStatus(rawValue: raw) == .complete,
              let pixels = buffer.imageBuffer,
              let surface = CVPixelBufferGetIOSurface(pixels)?.takeUnretainedValue(),
              let rectDictionary = metadata[.contentRect] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: rectDictionary),
              let contentScale = metadata[.contentScale] as? CGFloat,
              let scale = metadata[.scaleFactor] as? CGFloat else { return }
        continuation.yield(.frame(CapturedFrame(contentRect: rect, contentScale: contentScale,
                                                scaleFactor: scale, surface: surface)))
    }
}

// IOSurface is retained and only read by the compositor. No mutable surface access is exposed.
struct CapturedFrame: @unchecked Sendable {
    let contentRect: CGRect
    let contentScale: CGFloat
    let scaleFactor: CGFloat
    let surface: IOSurfaceRef
    var size: CGSize { contentRect.size }
}
