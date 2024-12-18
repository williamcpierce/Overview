/*
 Capture/CaptureManager.swift
 Overview

 Created by William Pierce on 9/15/24.

 Coordinates window capture lifecycle and state management, serving as the bridge
 between low-level capture operations and UI components. Manages window selection,
 capture permissions, frame delivery, and window state tracking while maintaining
 proper state synchronization across the capture system.
*/

import Combine
import ScreenCaptureKit

@MainActor
class CaptureManager: ObservableObject {
    @Published private(set) var capturedFrame: CapturedFrame?
    @Published private(set) var availableWindows: [SCWindow] = []
    @Published private(set) var isCapturing = false
    @Published private(set) var isSourceWindowFocused = false
    @Published private(set) var windowTitle: String?

    @Published var selectedWindow: SCWindow? {
        didSet {
            windowTitle = selectedWindow?.title
            Task { await synchronizeWindowFocusState() }
        }
    }

    private var settingsSubscriptions = Set<AnyCancellable>()
    private var activeFrameProcessingTask: Task<Void, Never>?
    private var windowStateObserverId: UUID?

    private let windowServices = WindowServices.shared
    private let userSettings: AppSettings
    private let streamEngine: CaptureEngine
    private let streamConfigurationService: StreamConfigurationService

    init(
        appSettings: AppSettings,
        captureEngine: CaptureEngine = CaptureEngine(),
        streamConfig: StreamConfigurationService = StreamConfigurationService()
    ) {
        self.userSettings = appSettings
        self.streamEngine = captureEngine
        self.streamConfigurationService = streamConfig
        initializeWindowStateObservers()
    }

    func requestPermission() async throws {
        try await windowServices.shareableContent.requestPermission()
    }

    func updateAvailableWindows() async {
        do {
            let windows = try await windowServices.shareableContent.getAvailableWindows()
            await MainActor.run {
                self.availableWindows = windowServices.windowFilter.filterWindows(windows)
            }
        } catch {
            AppLogger.capture.logError(
                error,
                context: "Failed to get available windows")
        }
    }

    func startCapture() async throws {
        guard !isCapturing else { return }
        guard let targetWindow = selectedWindow else { throw CaptureError.noWindowSelected }

        let (config, filter) = streamConfigurationService.createConfiguration(
            targetWindow, frameRate: userSettings.frameRate)
        let frameStream = streamEngine.startCapture(configuration: config, filter: filter)

        await startFrameProcessing(stream: frameStream)
        isCapturing = true
    }

    func stopCapture() async {
        guard isCapturing else { return }

        activeFrameProcessingTask?.cancel()
        activeFrameProcessingTask = nil
        await streamEngine.stopCapture()

        isCapturing = false
        capturedFrame = nil
    }

    func focusWindow(isEditModeEnabled: Bool) {
        guard let targetWindow = selectedWindow else { return }
        windowServices.windowFocus.focusWindow(
            window: targetWindow, isEditModeEnabled: isEditModeEnabled)
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

        userSettings.$frameRate
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.synchronizeStreamConfiguration() }
            }
            .store(in: &settingsSubscriptions)
    }

    @MainActor
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
        AppLogger.capture.logError(
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
            try await streamConfigurationService.updateConfiguration(
                streamEngine.stream,
                targetWindow,
                frameRate: userSettings.frameRate)
        } catch {
            AppLogger.capture.logError(
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
