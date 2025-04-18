/*
 Capture/CaptureCoordinator.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages the lifecycle of each screen capture operation, coordinating source
 window selection, frame processing, and state synchronization.
*/

import Combine
import Defaults
import ScreenCaptureKit
import SwiftUI

@MainActor
final class CaptureCoordinator: ObservableObject {
    // Published State
    @Published private(set) var capturedFrame: CapturedFrame?
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var isSourceAppFocused: Bool = false
    @Published private(set) var isSourceWindowFocused: Bool = false
    @Published private(set) var sourceWindowTitle: String?
    @Published private(set) var sourceApplicationTitle: String?
    @Published var selectedSource: SCWindow? {
        didSet {
            sourceWindowTitle = selectedSource?.title
            sourceApplicationTitle = selectedSource?.owningApplication?.applicationName
            Task { await synchronizeFocusState() }
        }
    }

    // Dependencies
    private var sourceManager: SourceManager
    private var permissionManager: PermissionManager
    private let captureEngine: CaptureEngine
    private let captureServices: CaptureServices = CaptureServices.shared
    private let logger = AppLogger.capture

    // Private State
    private var hasPermission: Bool = false
    private var activeFrameProcessingTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    init(
        sourceManager: SourceManager,
        permissionManager: PermissionManager,
        captureEngine: CaptureEngine = CaptureEngine()
    ) {
        self.sourceManager = sourceManager
        self.permissionManager = permissionManager
        self.captureEngine = captureEngine
        setupSubscriptions()
    }

    // MARK: - Public Interface

    func requestPermission() async throws {
        guard !hasPermission else { return }
        logger.debug("Requesting screen recording permission")
        try await permissionManager.ensurePermission()
        hasPermission = true
        logger.info("Screen recording permission granted")
    }

    func startCapture() async throws {
        guard !isCapturing else { return }

        guard let source: SCWindow = selectedSource else {
            logger.error("Capture failed: No source window selected")
            throw CaptureError.noSourceSelected
        }

        logger.debug("Starting capture for source window: '\(source.title ?? "Untitled")'")

        let stream = try await captureServices.startCapture(
            source: source,
            engine: captureEngine,
            frameRate: Defaults[.captureFrameRate]
        )

        await processFrames(from: stream)

        isCapturing = true
        logger.info("Capture started: '\(source.title ?? "Untitled")'")
    }

    func stopCapture() async {
        guard isCapturing else { return }

        activeFrameProcessingTask?.cancel()
        activeFrameProcessingTask = nil

        await captureEngine.stopCapture()

        isCapturing = false
        capturedFrame = nil
        logger.debug("Capture stopped")
    }

    func updateStreamConfiguration() async {
        guard isCapturing, let source: SCWindow = selectedSource else { return }
        logger.debug("Updating stream configuration: frameRate=\(Defaults[.captureFrameRate])")

        do {
            try await captureServices.updateStreamConfiguration(
                source: source,
                stream: captureEngine.stream,
                frameRate: Defaults[.captureFrameRate]
            )
            logger.info("Stream configuration updated successfully")
        } catch {
            logger.logError(error, context: "Failed to update stream configuration")
        }
    }

    func focusSource() {
        guard let source: SCWindow = selectedSource else { return }
        logger.debug("Focusing source window: '\(source.title ?? "Untitled")'")
        sourceManager.focusSource(source)
    }

    // MARK: - Frame Processing

    private func processFrames(from stream: AsyncThrowingStream<CapturedFrame, Error>) async {
        activeFrameProcessingTask?.cancel()

        activeFrameProcessingTask = Task { @MainActor in
            do {
                for try await frame in stream {
                    if Task.isCancelled { break }

                    self.capturedFrame = frame
                }

                if !Task.isCancelled {
                    logger.debug("Stream ended normally")
                    isCapturing = false
                }

            } catch let error as SCStreamError {
                await handleStreamError(error)

            } catch {
                logger.warning("Capture ended with error: \(error.localizedDescription)")

                if isCapturing {
                    await recoverFromError()
                }
            }
        }
    }

    private func handleStreamError(_ error: SCStreamError) async {
        let errorDescription = error.localizedDescription

        if error.code.isFatal {
            logger.logError(error, context: "Fatal stream error: \(errorDescription)")
            await stopCapture()
        } else {
            logger.warning("Recoverable stream error: \(errorDescription)")
            await recoverFromError()
        }
    }

    private func recoverFromError() async {
        guard isCapturing else { return }

        logger.debug("Attempting to recover from capture error")

        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        do {
            try await startCapture()
            logger.info("Successfully recovered from capture error")
        } catch {
            logger.logError(error, context: "Failed to recover from capture error")
            isCapturing = false
        }
    }

    // MARK: - State Synchronization

    private func setupSubscriptions() {
        sourceManager.$focusedProcessId
            .sink { [weak self] _ in Task { await self?.synchronizeFocusState() } }
            .store(in: &subscriptions)

        sourceManager.$sourceTitles
            .sink { [weak self] titles in self?.synchronizeSourceTitle(from: titles) }
            .store(in: &subscriptions)
    }

    private func synchronizeFocusState() async {
        guard let selectedSource: SCWindow = selectedSource else {
            isSourceWindowFocused = false
            return
        }

        let selectedProcessId: pid_t? = selectedSource.owningApplication?.processID
        let selectedBundleId: String? = selectedSource.owningApplication?.bundleIdentifier

        isSourceWindowFocused = selectedProcessId == sourceManager.focusedProcessId
        isSourceAppFocused = selectedBundleId == sourceManager.focusedBundleId
    }

    private func synchronizeSourceTitle(from titles: [SourceManager.SourceID: String]) {
        guard let source: SCWindow = selectedSource,
            let processID: pid_t = source.owningApplication?.processID
        else { return }

        let sourceID = SourceManager.SourceID(processID: processID, windowID: source.windowID)
        sourceWindowTitle = titles[sourceID]
        sourceApplicationTitle = source.owningApplication?.applicationName
    }
}

// MARK - Support Types

enum CaptureError: LocalizedError {
    case noSourceSelected
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noSourceSelected:
            return "No source window is selected for capture"
        case .permissionDenied:
            return "Screen capture permission was denied"
        }
    }
}

extension SCStreamError.Code {
    var isFatal: Bool {
        switch self {
        case .userDeclined, .missingEntitlements, .userStopped,
            .noCaptureSource, .noWindowList,
            .failedApplicationConnectionInvalid,
            .failedApplicationConnectionInterrupted,
            .failedNoMatchingApplicationContext,
            .systemStoppedStream, .internalError:
            return true
        default:
            return false
        }
    }
}
