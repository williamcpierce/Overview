/*
 CaptureManager.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages window capture lifecycle and state synchronization between the capture
 stream and UI components, providing a high-level interface for window previews.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import Combine
import ScreenCaptureKit

/// Manages window capture state and coordinates preview operations
///
/// Key responsibilities:
/// - Coordinates window selection and focus state tracking
/// - Maintains captured frame state for preview rendering
/// - Manages capture session lifecycle and permissions
/// - Synchronizes capture configuration with user settings
///
/// Coordinates with:
/// - PreviewView: Provides frame data and window state
/// - SelectionView: Handles window setup and initialization
/// - AppSettings: Applies user configuration to capture
/// - CaptureEngine: Manages low-level stream operations
@MainActor
class CaptureManager: ObservableObject {
    // MARK: - Properties

    /// Most recent frame from the source window
    /// - Note: Updates trigger immediate UI refresh
    @Published private(set) var capturedFrame: CapturedFrame?

    /// Available windows for capture, filtered to remove system windows
    @Published private(set) var availableWindows: [SCWindow] = []

    /// Whether capture is active and delivering frames
    @Published private(set) var isCapturing = false

    /// Whether the source window has system focus
    @Published private(set) var isSourceWindowFocused = false

    /// Title of the currently selected window
    @Published private(set) var windowTitle: String?

    /// Currently selected window for capture
    /// - Note: Changes trigger focus state updates
    @Published var selectedWindow: SCWindow? {
        didSet {
            windowTitle = selectedWindow?.title
            Task { await updateFocusState() }
        }
    }

    // MARK: - Private Properties

    /// Active Combine subscriptions for cleanup
    private var cancellables = Set<AnyCancellable>()

    /// Current capture operation
    /// - Warning: Must be cancelled before starting new capture
    private var captureTask: Task<Void, Never>?
    private var observerId: UUID?

    // MARK: - Service Dependencies

    private let services = WindowServices.shared

    /// User-configured settings for capture behavior
    private let appSettings: AppSettings

    /// Low-level screen capture operations
    private let captureEngine: CaptureEngine

    /// Capture stream parameters
    private let streamConfig: StreamConfigurationService

    // MARK: - Initialization

    init(
        appSettings: AppSettings,
        captureEngine: CaptureEngine = CaptureEngine(),
        streamConfig: StreamConfigurationService = StreamConfigurationService()
    ) {
        AppLogger.capture.debug("Initializing CaptureManager")

        self.appSettings = appSettings
        self.captureEngine = captureEngine
        self.streamConfig = streamConfig

        setupObservers()

        AppLogger.capture.info("CaptureManager initialized successfully")
    }

    // MARK: - Public Methods

    /// Requests screen capture permission from the system
    /// - Throws: CaptureError.permissionDenied if access is not granted
    func requestPermission() async throws {
        AppLogger.capture.debug("Requesting screen capture permission")
        try await services.shareableContent.requestPermission()
        AppLogger.capture.info("Screen capture permission granted")
    }

    /// Updates the list of available windows for capture
    ///
    /// Flow:
    /// 1. Retrieves current window list
    /// 2. Filters out invalid capture targets
    /// 3. Updates available windows property
    func updateAvailableWindows() async {
        AppLogger.capture.debug("Updating available windows list")

        do {
            let windows = try await services.shareableContent.getAvailableWindows()
            await MainActor.run {
                self.availableWindows = services.windowFilter.filterWindows(windows)
            }
            AppLogger.capture.info(
                "Available windows updated, count: \(self.availableWindows.count)")
        } catch {
            AppLogger.logError(
                error,
                context: "Failed to get available windows",
                logger: AppLogger.capture)
        }
    }

    /// Initiates window capture with current configuration
    ///
    /// Flow:
    /// 1. Validates window selection and state
    /// 2. Creates stream configuration
    /// 3. Starts capture engine
    ///
    /// - Throws:
    ///   - CaptureError.noWindowSelected if no window selected
    ///   - CaptureError.captureStreamFailed for initialization failures
    func startCapture() async throws {
        guard !isCapturing else {
            AppLogger.capture.debug("Capture already active, ignoring start request")
            return
        }

        guard let window = selectedWindow else {
            AppLogger.capture.warning("Attempted to start capture with no window selected")
            throw CaptureError.noWindowSelected
        }

        AppLogger.capture.debug("Starting capture for window: '\(window.title ?? "untitled")'")

        let (config, filter) = streamConfig.createConfiguration(
            window, frameRate: appSettings.frameRate)
        let frameStream = captureEngine.startCapture(configuration: config, filter: filter)

        await startCaptureTask(frameStream: frameStream)
        isCapturing = true

        AppLogger.capture.info("Capture started successfully")
    }

    /// Stops the current capture session
    ///
    /// Flow:
    /// 1. Cancels active capture task
    /// 2. Stops capture engine
    /// 3. Resets capture state
    func stopCapture() async {
        guard isCapturing else {
            AppLogger.capture.debug("No active capture to stop")
            return
        }

        AppLogger.capture.debug("Stopping capture session")

        captureTask?.cancel()
        captureTask = nil
        await captureEngine.stopCapture()

        isCapturing = false
        capturedFrame = nil

        AppLogger.capture.info("Capture stopped successfully")
    }

    /// Brings source window to front when preview is clicked
    /// - Parameter isEditModeEnabled: Whether edit mode is active
    func focusWindow(isEditModeEnabled: Bool) {
        guard let window = selectedWindow else {
            AppLogger.windows.warning("Attempted to focus window with no selection")
            return
        }

        AppLogger.windows.debug("Focusing window: '\(window.title ?? "untitled")'")
        services.windowFocus.focusWindow(window: window, isEditModeEnabled: isEditModeEnabled)
    }

    // MARK: - Private Methods

    /// Starts new capture task for processing frames
    /// - Parameter frameStream: Stream of captured frames from engine
    @MainActor
    private func startCaptureTask(frameStream: AsyncThrowingStream<CapturedFrame, Error>) async {
        AppLogger.capture.debug("Initializing capture task")

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
    ///
    /// Flow:
    /// 1. Logs error details
    /// 2. Stops capture session
    /// 3. Updates UI state
    private func handleCaptureError(_ error: Error) async {
        AppLogger.logError(
            error,
            context: "Capture stream error",
            logger: AppLogger.capture)
        await stopCapture()
    }

    /// Sets up observers for window state changes
    ///
    /// Flow:
    /// 1. Configures focus monitoring
    /// 2. Sets up title tracking
    /// 3. Starts observation
    /// 4. Configures frame rate handling
    private func setupObservers() {
        AppLogger.capture.debug("Setting up window state observers")

        // Register for window state updates with unique identifier
        let observerId = UUID()
        self.observerId = observerId
        services.windowObserver.addObserver(
            id: observerId,
            onFocusChanged: { [weak self] in
                await self?.updateFocusState()
            },
            onTitleChanged: { [weak self] in
                await self?.updateWindowTitle()
            }
        )

        // Context: Frame rate changes require stream reconfiguration
        appSettings.$frameRate
            .dropFirst()
            .sink { [weak self] _ in
                Task {
                    await self?.updateStreamConfiguration()
                }
            }
            .store(in: &cancellables)

        AppLogger.capture.debug("Window state observers configured")
    }

    /// Updates focus state of the source window
    private func updateFocusState() async {
        isSourceWindowFocused = await services.windowFocus.updateFocusState(for: selectedWindow)

        if let window = selectedWindow {
            AppLogger.windows.debug(
                "Window focus state updated: '\(window.title ?? "untitled")' focused: \(isSourceWindowFocused)"
            )
        }
    }

    /// Updates title of the source window
    private func updateWindowTitle() async {
        let oldTitle = windowTitle
        windowTitle = await services.titleService.updateWindowTitle(for: selectedWindow)

        if let newTitle = windowTitle, oldTitle != newTitle {
            AppLogger.windows.debug("Window title updated: '\(newTitle)'")
        }
    }

    /// Updates capture configuration when settings change
    /// - Warning: Frame rate changes require stream reconfiguration
    private func updateStreamConfiguration() async {
        guard isCapturing, let window = selectedWindow else { return }

        AppLogger.capture.debug(
            "Updating stream configuration, new frame rate: \(appSettings.frameRate)")

        do {
            try await streamConfig.updateConfiguration(
                captureEngine.stream, window, frameRate: appSettings.frameRate)
            AppLogger.capture.info("Stream configuration updated successfully")
        } catch {
            AppLogger.logError(
                error,
                context: "Failed to update stream configuration",
                logger: AppLogger.capture)
        }
    }
}

/// Error cases that can occur during window capture operations
enum CaptureError: LocalizedError {
    /// Screen recording permission was denied by the user or system
    case permissionDenied

    /// Attempted to start capture without selecting a window
    case noWindowSelected

    /// Capture stream failed to initialize or encountered an error
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
