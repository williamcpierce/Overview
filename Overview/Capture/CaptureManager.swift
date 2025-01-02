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
    @ObservedObject private var appSettings: AppSettings

    @Published private(set) var capturedFrame: CapturedFrame?
    @Published private(set) var availableWindows: [SCWindow] = []
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var isSourceWindowFocused: Bool = false
    @Published private(set) var windowTitle: String?
    @Published var selectedWindow: SCWindow? {
        didSet {
            windowTitle = selectedWindow?.title
            Task { await synchronizeWindowFocusState() }
        }
    }

    private let windowServices = WindowServices.shared
    private let captureServices = CaptureServices.shared
    private let captureEngine: CaptureEngine
    private let logger = AppLogger.capture

    private var settingsSubscriptions = Set<AnyCancellable>()
    private var activeFrameProcessingTask: Task<Void, Never>?
    private var windowStateObserverId: UUID?
    private var hasPermission: Bool = false

    init(
        appSettings: AppSettings,
        captureEngine: CaptureEngine = CaptureEngine()
    ) {
        self.appSettings = appSettings
        self.captureEngine = captureEngine
        initializeWindowStateObservers()
    }

    func requestPermission() async throws {
        guard !hasPermission else { return }

        do {
            try await captureServices.captureAvailability.requestPermission()
            hasPermission = true
        } catch {
            logger.logError(
                error,
                context: "Failed to request screen recording permission")
        }
    }

    func updateAvailableWindows() async {
        do {
            let windows = try await captureServices.captureAvailability.getAvailableWindows()
            await MainActor.run {
                self.availableWindows = windowServices.windowFilter.filterWindows(windows)
            }
        } catch {
            logger.logError(
                error,
                context: "Failed to get available windows")
        }
    }

    func startCapture() async throws {
        guard !isCapturing else { return }
        guard let targetWindow = selectedWindow else { throw CaptureError.noWindowSelected }

        let (config, filter) = captureServices.captureConfiguration.createConfiguration(
            targetWindow, frameRate: appSettings.frameRate)
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
        guard let targetWindow = selectedWindow else { return }
        windowServices.windowFocus.focusWindow(
            window: targetWindow)
    }

    private func initializeWindowStateObservers() {
        let observerId = UUID()
        self.windowStateObserverId = observerId

        windowServices.windowObserver.addObserver(
            id: observerId,
            onFocusChanged: { [weak self] in
                await self?.synchronizeWindowFocusState()
            },
            onTitleChanged: { [weak self] in
                await self?.synchronizeWindowTitle()
            }
        )

        appSettings.$frameRate
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.synchronizeStreamConfiguration() }
            }
            .store(in: &settingsSubscriptions)
    }

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

    private func synchronizeWindowFocusState() async {
        isSourceWindowFocused = await windowServices.windowFocus.updateFocusState(
            for: selectedWindow)
    }

    private func synchronizeWindowTitle() async {
        windowTitle = await windowServices.titleService.updateWindowTitle(for: selectedWindow)
    }

    private func synchronizeStreamConfiguration() async {
        guard isCapturing, let targetWindow = selectedWindow else { return }

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
    case permissionDenied
    case noWindowSelected
    case captureStreamFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen capture permission was denied"
        case .noWindowSelected:
            return "No window is selected for capture"
        case .captureStreamFailed(let error):
            return "Capture failed: \(error.localizedDescription)"
        }
    }
}
