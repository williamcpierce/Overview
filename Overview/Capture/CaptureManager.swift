/*
 Capture/CaptureManager.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages the lifecycle of screen capture operations, coordinating window selection,
 frame processing, and state synchronization across the application.
*/

import Combine
import ScreenCaptureKit
import SwiftUI

@MainActor
final class CaptureManager: ObservableObject {
    // MARK: - Published State
    @Published private(set) var capturedFrame: CapturedFrame?
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var isSourceAppFocused: Bool = false
    @Published private(set) var isSourceWindowFocused: Bool = false
    @Published private(set) var windowTitle: String?
    @Published var selectedWindow: SCWindow? {
        didSet {
            windowTitle = selectedWindow?.title
            Task { await synchronizeFocusState() }
        }
    }

    // MARK: - Dependencies
    private let appSettings: AppSettings
    private let windowManager: WindowManager
    private let captureEngine: CaptureEngine
    private let captureServices: CaptureServices = CaptureServices.shared
    private let logger = AppLogger.capture

    // MARK: - State Management
    private var hasPermission: Bool = false
    private var activeFrameProcessingTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    init(
        appSettings: AppSettings,
        windowManager: WindowManager,
        captureEngine: CaptureEngine = CaptureEngine()
    ) {
        self.appSettings = appSettings
        self.windowManager = windowManager
        self.captureEngine = captureEngine
        setupSubscriptions()
    }

    // MARK: - Public Interface

    func requestPermission() async throws {
        guard !hasPermission else { return }
        logger.debug("Requesting screen recording permission")
        try await captureServices.requestScreenRecordingPermission()
        hasPermission = true
        logger.info("Screen recording permission granted")
    }

    func startCapture() async throws {
        guard !isCapturing else { return }
        guard let window: SCWindow = selectedWindow else {
            logger.error("Capture failed: No window selected")
            throw CaptureError.noWindowSelected
        }

        logger.debug("Starting capture for window: '\(window.title ?? "Untitled")'")
        let stream = try await captureServices.startCapture(
            window: window,
            engine: captureEngine,
            frameRate: appSettings.frameRate
        )

        await startFrameProcessing(stream: stream)
        isCapturing = true
        logger.info("Capture started: '\(window.title ?? "Untitled")'")
    }

    func stopCapture() async {
        guard isCapturing else { return }
        logger.debug("Stopping capture")

        activeFrameProcessingTask?.cancel()
        activeFrameProcessingTask = nil
        await captureEngine.stopCapture()
        isCapturing = false
        capturedFrame = nil
        logger.info("Capture stopped")
    }

    func focusWindow() {
        guard let window: SCWindow = selectedWindow else { return }
        logger.debug("Focusing window: '\(window.title ?? "Untitled")'")
        windowManager.focusWindow(window)
    }

    // MARK: - Private Methods

    private func startFrameProcessing(stream: AsyncThrowingStream<CapturedFrame, Error>) async {
        activeFrameProcessingTask?.cancel()

        activeFrameProcessingTask = Task { @MainActor in
            do {
                for try await frame in stream {
                    self.capturedFrame = frame
                }
            } catch {
                await self.handleCaptureFailure(error)
            }
        }
    }

    private func handleCaptureFailure(_ error: Error) async {
        logger.logError(error, context: "Capture stream error")
        await stopCapture()
    }

    private func setupSubscriptions() {
        windowManager.$focusedProcessId
            .sink { [weak self] _ in Task { await self?.synchronizeFocusState() } }
            .store(in: &subscriptions)

        windowManager.$windowTitles
            .sink { [weak self] titles in self?.synchronizeWindowTitle(from: titles) }
            .store(in: &subscriptions)

        appSettings.$frameRate
            .dropFirst()
            .sink { [weak self] _ in Task { await self?.synchronizeStreamConfiguration() } }
            .store(in: &subscriptions)
    }

    private func synchronizeFocusState() async {
        guard let selectedWindow: SCWindow = selectedWindow else {
            isSourceWindowFocused = false
            return
        }

        let selectedProcessId: pid_t? = selectedWindow.owningApplication?.processID
        let selectedBundleId: String? = selectedWindow.owningApplication?.bundleIdentifier

        isSourceWindowFocused = selectedProcessId == windowManager.focusedProcessId
        isSourceAppFocused = selectedBundleId == windowManager.focusedBundleId

        logger.debug(
            "Focus state updated: window=\(isSourceWindowFocused), app=\(isSourceAppFocused)"
        )
    }

    private func synchronizeWindowTitle(from titles: [WindowManager.WindowID: String]) {
        guard let window: SCWindow = selectedWindow,
            let processID: pid_t = window.owningApplication?.processID
        else { return }

        let windowID = WindowManager.WindowID(processID: processID, windowID: window.windowID)
        windowTitle = titles[windowID]
    }

    private func synchronizeStreamConfiguration() async {
        guard isCapturing, let window: SCWindow = selectedWindow else { return }
        logger.debug("Updating stream configuration: frameRate=\(appSettings.frameRate)")

        do {
            try await captureServices.updateStreamConfiguration(
                window: window,
                stream: captureEngine.stream,
                frameRate: appSettings.frameRate
            )
            logger.info("Stream configuration updated successfully")
        } catch {
            logger.logError(error, context: "Failed to update stream configuration")
        }
    }
}
