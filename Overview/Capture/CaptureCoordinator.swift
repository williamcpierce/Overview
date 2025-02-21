/*
 Capture/CaptureCoordinator.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages the lifecycle of each screen capture operation, coordinating source
 window selection, frame processing, and state synchronization.
*/

import Combine
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
            synchronizeFocusState(with: sourceManager.focusedWindow)
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

    // Preview Settings
    @AppStorage(PreviewSettingsKeys.captureFrameRate)
    private var captureFrameRate = PreviewSettingsKeys.defaults.captureFrameRate

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
        try await permissionManager.ensurePermissions()
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
            frameRate: captureFrameRate
        )

        await startFrameProcessing(stream: stream)
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
        logger.debug("Updating stream configuration: frameRate=\(captureFrameRate)")

        do {
            try await captureServices.updateStreamConfiguration(
                source: source,
                stream: captureEngine.stream,
                frameRate: captureFrameRate
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

    private func startFrameProcessing(stream: AsyncThrowingStream<CapturedFrame, Error>) async {
        activeFrameProcessingTask?.cancel()

        activeFrameProcessingTask = Task { @MainActor in
            do {
                for try await frame in stream {
                    self.capturedFrame = frame
                }
            } catch {
                await handleCaptureError(error)
            }
        }
    }

    private func handleCaptureError(_ error: Error) async {
        if let scError = error as? SCStreamError, scError.code.isFatal {
            logger.logError(error, context: "Fatal capture error")
            await stopCapture()
        } else {
            logger.warning("Recoverable capture error: \(error.localizedDescription)")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            try? await startCapture()
        }
    }

    // MARK: - State Synchronization

    private func setupSubscriptions() {
        sourceManager.$focusedWindow
            .sink { [weak self] focusedWindow in self?.synchronizeFocusState(with: focusedWindow) }
            .store(in: &subscriptions)

        sourceManager.$sourceTitles
            .sink { [weak self] titles in self?.synchronizeSourceTitle(from: titles) }
            .store(in: &subscriptions)
    }

    private func synchronizeFocusState(with focusedWindow: FocusedWindow?) {
        guard let selectedSource = selectedSource else {
            isSourceWindowFocused = false
            isSourceAppFocused = false
            return
        }

        let selectedBundleId = selectedSource.owningApplication?.bundleIdentifier

        if let focusedWindow = focusedWindow {
            isSourceWindowFocused = selectedSource.windowID == focusedWindow.windowID
            isSourceAppFocused = selectedBundleId == focusedWindow.bundleID
        } else {
            isSourceWindowFocused = false
            isSourceAppFocused = false
        }

        // Update titles here to ensure they stay in sync with focus state
        synchronizeSourceTitle(from: sourceManager.sourceTitles)
    }

    private func synchronizeSourceTitle(from titles: [SourceManager.SourceID: String]) {
        guard let source = selectedSource,
            let processID = source.owningApplication?.processID
        else {
            sourceWindowTitle = nil
            sourceApplicationTitle = nil
            return
        }

        let sourceID = SourceManager.SourceID(processID: processID, windowID: source.windowID)

        // Prefer the title from sourceTitles if available, otherwise fall back to SCWindow title
        sourceWindowTitle = titles[sourceID] ?? source.title
        sourceApplicationTitle = source.owningApplication?.applicationName
    }
}

// MARK: - Support Types

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
