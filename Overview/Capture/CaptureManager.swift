/*
 CaptureManager.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import Combine
import OSLog
import ScreenCaptureKit

/// Manages window capture state and coordinates capture operations with UI components
///
/// Key responsibilities:
/// - Manages capture session lifecycle and configuration
/// - Coordinates window selection and focus state
/// - Handles capture permissions and errors
/// - Maintains captured frame state for preview rendering
///
/// Coordinates with:
/// - PreviewView: Provides captured frames and window state for display
/// - SelectionView: Handles window selection and capture initialization
/// - AppSettings: Applies user configuration to capture sessions
/// - CaptureEngine: Manages low-level capture stream operations
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

@MainActor
class CaptureManager: ObservableObject {
    // MARK: - Published Properties

    /// The most recent frame captured from the source window
    @Published var capturedFrame: CapturedFrame?

    /// List of windows available for capture, filtered by WindowFilterService
    @Published var availableWindows: [SCWindow] = []

    /// Whether capture is currently active
    @Published var isCapturing = false

    /// Whether the source window currently has focus
    @Published var isSourceWindowFocused = false

    /// Title of the currently selected window
    @Published var windowTitle: String?

    /// Currently selected window for capture
    @Published var selectedWindow: SCWindow? {
        didSet {
            windowTitle = selectedWindow?.title
            Task { await updateFocusState() }
        }
    }

    // MARK: - Private Properties

    /// Context: Logger is used across services for consistent error tracking
    private let logger = Logger(subsystem: "com.Overview.CaptureManager", category: "ScreenCapture")
    private var cancellables = Set<AnyCancellable>()
    private var captureTask: Task<Void, Never>?

    // MARK: - Dependencies

    /// Context: These services handle specific aspects of window capture and management
    private let appSettings: AppSettings
    private let captureEngine: CaptureEngine
    private let streamConfig: StreamConfigurationService
    private let windowFilter: WindowFilterService
    private let windowFocus: WindowFocusService
    private let titleService: WindowTitleService
    private let windowObserver: WindowObserverService
    private let shareableContent: ShareableContentService

    // MARK: - Initialization

    /// Initializes the capture manager with required services
    ///
    /// Flow:
    /// 1. Stores service dependencies
    /// 2. Sets up window state observers
    /// 3. Configures frame rate monitoring
    init(
        appSettings: AppSettings,
        captureEngine: CaptureEngine = CaptureEngine(),
        streamConfig: StreamConfigurationService = StreamConfigurationService(),
        windowFilter: WindowFilterService = WindowFilterService(),
        windowFocus: WindowFocusService = WindowFocusService(),
        titleService: WindowTitleService = WindowTitleService(),
        windowObserver: WindowObserverService = WindowObserverService(),
        shareableContent: ShareableContentService = ShareableContentService()
    ) {
        self.appSettings = appSettings
        self.captureEngine = captureEngine
        self.streamConfig = streamConfig
        self.windowFilter = windowFilter
        self.windowFocus = windowFocus
        self.titleService = titleService
        self.windowObserver = windowObserver
        self.shareableContent = shareableContent

        setupObservers()
    }

    // MARK: - Public Methods

    /// Requests screen capture permission from the system
    func requestPermission() async throws {
        try await shareableContent.requestPermission()
    }

    /// Updates the list of available windows for capture
    func updateAvailableWindows() async {
        do {
            let windows = try await shareableContent.getAvailableWindows()
            await MainActor.run {
                self.availableWindows = windowFilter.filterWindows(windows)
            }
        } catch {
            logger.error("Failed to get available windows: \(error.localizedDescription)")
        }
    }

    /// Initiates window capture with current configuration
    ///
    /// Flow:
    /// 1. Validates window selection
    /// 2. Configures capture stream
    /// 3. Begins frame processing
    ///
    /// - Throws: CaptureError.noWindowSelected if no window is selected
    ///          CaptureError.captureStreamFailed for stream initialization failures
    func startCapture() async throws {
        guard !isCapturing else { return }
        guard let window = selectedWindow else {
            throw CaptureError.noWindowSelected
        }

        let (config, filter) = streamConfig.createConfiguration(
            window, frameRate: appSettings.frameRate)
        let frameStream = captureEngine.startCapture(configuration: config, filter: filter)

        await startCaptureTask(frameStream: frameStream)
        isCapturing = true
    }

    /// Stops the current capture session
    func stopCapture() async {
        guard isCapturing else { return }

        captureTask?.cancel()
        captureTask = nil
        await captureEngine.stopCapture()

        isCapturing = false
        capturedFrame = nil
    }

    /// Brings the source window to front when preview is clicked
    ///
    /// - Parameter isEditModeEnabled: Whether edit mode is active
    func focusWindow(isEditModeEnabled: Bool) {
        guard let window = selectedWindow else { return }
        windowFocus.focusWindow(window: window, isEditModeEnabled: isEditModeEnabled)
    }

    // MARK: - Private Methods

    /// Starts a new capture task for processing frames
    @MainActor
    private func startCaptureTask(frameStream: AsyncThrowingStream<CapturedFrame, Error>) async {
        captureTask?.cancel()

        captureTask = Task { @MainActor in
            do {
                for try await frame in frameStream {
                    self.capturedFrame = frame
                }
            } catch {
                await self.handleCaptureError(error)
            }
        }
    }

    /// Handles errors during capture
    private func handleCaptureError(_ error: Error) async {
        logger.error("Capture error: \(error.localizedDescription)")
        await stopCapture()
    }

    /// Sets up observers for window state changes
    private func setupObservers() {
        windowObserver.onFocusStateChanged = { [weak self] in
            await self?.updateFocusState()
        }

        windowObserver.onWindowTitleChanged = { [weak self] in
            await self?.updateWindowTitle()
        }

        windowObserver.startObserving()

        /// WARNING: Frame rate changes require stream reconfiguration
        appSettings.$frameRate
            .dropFirst()
            .sink { [weak self] _ in
                Task {
                    await self?.updateStreamConfiguration()
                }
            }
            .store(in: &cancellables)
    }

    /// Updates the focus state of the source window
    private func updateFocusState() async {
        isSourceWindowFocused = await windowFocus.updateFocusState(for: selectedWindow)
    }

    /// Updates the title of the source window
    private func updateWindowTitle() async {
        windowTitle = await titleService.updateWindowTitle(for: selectedWindow)
    }

    /// Updates capture configuration when settings change
    private func updateStreamConfiguration() async {
        guard isCapturing, let window = selectedWindow else { return }
        try? await streamConfig.updateConfiguration(
            captureEngine.stream, window, frameRate: appSettings.frameRate)
    }
}
