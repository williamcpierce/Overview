/*
 Capture/CaptureManager.swift
 Overview

 Created by William Pierce on 9/15/24.
*/

import Combine
import ScreenCaptureKit
import SwiftUI

@MainActor
class CaptureManager: ObservableObject {
    // MARK: - Published State
    @Published private(set) var availableWindows: [SCWindow] = []
    @Published private(set) var capturedFrame: CapturedFrame?
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var isSourceWindowFocused: Bool = false
    @Published private(set) var windowTitle: String?
    @Published var selectedWindow: SCWindow? {
        didSet {
            windowTitle = selectedWindow?.title
            Task { await synchronizeWindowFocusState() }
        }
    }

    // MARK: - Dependencies
    @ObservedObject private var appSettings: AppSettings
    @ObservedObject private var windowManager: WindowManager
    private let captureEngine: CaptureEngine
    private let captureServices: CaptureServices = CaptureServices.shared
    private let logger = AppLogger.capture

    // MARK: - Private State
    private var hasPermission = false
    private var activeFrameProcessingTask: Task<Void, Never>?
    private var settingsSubscriptions = Set<AnyCancellable>()

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
        try await captureServices.captureAvailability.requestPermission()
        hasPermission = true
    }

    func updateAvailableWindows() async {
        do {
            let windows = try await captureServices.captureAvailability.getAvailableWindows()
            await MainActor.run {
                availableWindows = windowManager.windowServices.windowFilter.filterWindows(windows)
            }
        } catch {
            logger.logError(error, context: "Failed to get available windows")
        }
    }

    func startCapture() async throws {
        guard !isCapturing else { return }
        guard let window = selectedWindow else { throw CaptureError.noWindowSelected }

        let (config, filter) = captureServices.captureConfiguration.createConfiguration(
            window, frameRate: appSettings.frameRate)
        let frameStream = captureEngine.startCapture(configuration: config, filter: filter)

        await startFrameProcessing(stream: frameStream)
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
        windowManager.windowServices.windowFocus.focusWindow(window: window)
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
        logger.logError(
            error,
            context: "Capture stream error")
        await stopCapture()
    }

    private func setupSubscriptions() {
        windowManager.$focusedBundleId
            .sink { [weak self] _ in Task { await self?.synchronizeWindowFocusState() } }
            .store(in: &settingsSubscriptions)

        windowManager.$windowTitles
            .sink { [weak self] titles in self?.synchronizeWindowTitle(from: titles) }
            .store(in: &settingsSubscriptions)

        appSettings.$frameRate
            .dropFirst()
            .sink { [weak self] _ in Task { await self?.synchronizeStreamConfiguration() } }
            .store(in: &settingsSubscriptions)
    }

    private func synchronizeWindowFocusState() async {
        guard let selectedWindow = selectedWindow,
            let selectedBundleId = selectedWindow.owningApplication?.bundleIdentifier,
            let focusedBundleId = windowManager.focusedBundleId
        else {
            isSourceWindowFocused = false
            return
        }
        isSourceWindowFocused = selectedBundleId == focusedBundleId
    }

    private func synchronizeWindowTitle(from titles: [WindowManager.WindowID: String]) {
        guard let window = selectedWindow,
            let processID = window.owningApplication?.processID
        else { return }
        let windowID = WindowManager.WindowID(processID: processID, windowID: window.windowID)
        windowTitle = titles[windowID]
    }

    private func synchronizeStreamConfiguration() async {
        guard isCapturing, let targetWindow: SCWindow = selectedWindow else { return }

        do {
            try await captureServices.captureConfiguration.updateConfiguration(
                captureEngine.stream,
                targetWindow,
                frameRate: appSettings.frameRate)
        } catch {
            logger.logError(
                error,
                context: "Failed to update stream configuration")
        }
    }
}

enum CaptureError: LocalizedError {
    case captureStreamFailed(Error)
    case noWindowSelected
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .captureStreamFailed(let error):
            return "Capture failed: \(error.localizedDescription)"
        case .noWindowSelected:
            return "No window is selected for capture"
        case .permissionDenied:
            return "Screen capture permission was denied"
        }
    }
}
