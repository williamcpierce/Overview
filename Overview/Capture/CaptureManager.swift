/*
 Capture/CaptureManager.swift
 Overview

 Created by William Pierce on 9/15/24.
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
    private var hasPermission = false
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
        try await captureServices.requestScreenRecordingPermission()
        hasPermission = true
    }

    func startCapture() async throws {
        guard !isCapturing else { return }
        guard let window = selectedWindow else { throw CaptureError.noWindowSelected }

        let stream = try await captureServices.startCapture(
            window: window,
            engine: captureEngine,
            frameRate: appSettings.frameRate
        )

        await startFrameProcessing(stream: stream)
        isCapturing = true
    }

    func stopCapture() async {
        guard isCapturing else { return }
        activeFrameProcessingTask?.cancel()
        activeFrameProcessingTask = nil
        await captureEngine.stopCapture()
        isCapturing = false
        capturedFrame = nil
    }

    func focusWindow() {
        guard let window = selectedWindow else { return }
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
        guard let selectedWindow = selectedWindow else {
            isSourceWindowFocused = false
            return
        }
        let selectedProcessId: pid_t? = selectedWindow.owningApplication?.processID
        let selectedBundleId: String? = selectedWindow.owningApplication?.bundleIdentifier

        isSourceWindowFocused = selectedProcessId == windowManager.focusedProcessId
        isSourceAppFocused = selectedBundleId == windowManager.focusedBundleId
    }

    private func synchronizeWindowTitle(from titles: [WindowManager.WindowID: String]) {
        guard let window = selectedWindow,
            let processID = window.owningApplication?.processID
        else { return }
        let windowID = WindowManager.WindowID(processID: processID, windowID: window.windowID)
        windowTitle = titles[windowID]
    }

    private func synchronizeStreamConfiguration() async {
        guard isCapturing, let window = selectedWindow else { return }

        do {
            try await captureServices.updateStreamConfiguration(
                window: window,
                stream: captureEngine.stream,
                frameRate: appSettings.frameRate
            )
        } catch {
            logger.logError(error, context: "Failed to update stream configuration")
        }
    }
}
