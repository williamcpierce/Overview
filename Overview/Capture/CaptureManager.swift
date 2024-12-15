/*
 CaptureManager.swift
 Overview

 Created by William Pierce on 9/15/24.

 Coordinates window capture lifecycle and state management, serving as the bridge
 between low-level capture operations and UI components. Manages window selection,
 capture permissions, frame delivery, and window state tracking while maintaining
 proper state synchronization across the capture system.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import Combine
import ScreenCaptureKit

/// Manages window capture operations and state synchronization for preview windows
///
/// Key responsibilities:
/// - Handles window selection and capture permission workflow
/// - Maintains captured frame state for preview rendering
/// - Manages capture session lifecycle and error handling
/// - Tracks window focus and title state changes
/// - Coordinates capture configuration with user settings
///
/// Coordinates with:
/// - PreviewView: Provides frame data and window state updates
/// - SelectionView: Handles window selection and permission flow
/// - AppSettings: Applies user preferences to capture configuration
/// - WindowServices: Manages window filtering and state tracking
/// - CaptureEngine: Controls low-level capture stream operations
@MainActor
class CaptureManager: ObservableObject {
    // MARK: - Properties

    /// Most recent frame from capture stream
    /// - Note: Updates trigger immediate UI refresh
    @Published private(set) var capturedFrame: CapturedFrame?

    /// Windows available for capture, filtered to exclude system UI
    @Published private(set) var availableWindows: [SCWindow] = []

    /// Whether capture stream is active and delivering frames
    @Published private(set) var isCapturing = false

    /// Whether source window currently has system focus
    @Published private(set) var isSourceWindowFocused = false

    /// Title of currently selected window for display
    @Published private(set) var windowTitle: String?

    /// Currently selected window for capture operations
    /// - Note: Changes trigger immediate focus state updates
    @Published var selectedWindow: SCWindow? {
        didSet {
            windowTitle = selectedWindow?.title
            Task { await updateFocusState() }
        }
    }

    // MARK: - Private Properties

    /// Active subscriptions for settings changes
    /// - Note: Cleaned up automatically when manager is deallocated
    private var cancellables = Set<AnyCancellable>()

    /// Current capture processing task
    /// - Warning: Must be cancelled before starting new capture
    private var captureTask: Task<Void, Never>?

    /// Observer ID for window state tracking
    /// - Note: Used to remove observer during cleanup
    private var observerId: UUID?

    // MARK: - Service Dependencies

    /// Access to shared window management services
    private let services = WindowServices.shared

    /// User preferences for capture behavior
    private let appSettings: AppSettings

    /// Low-level capture stream management
    private let captureEngine: CaptureEngine

    /// Stream configuration management
    private let streamConfig: StreamConfigurationService

    // MARK: - Initialization

    /// Creates capture manager with required dependencies
    ///
    /// Flow:
    /// 1. Stores service references
    /// 2. Initializes state tracking
    /// 3. Sets up settings observers
    ///
    /// - Parameters:
    ///   - appSettings: User preferences for capture configuration
    ///   - captureEngine: Stream management (defaults to new instance)
    ///   - streamConfig: Configuration service (defaults to new instance)
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

    /// Requests screen recording permission from the system
    ///
    /// Flow:
    /// 1. Prompts system permission dialog
    /// 2. Awaits user response
    /// 3. Validates permission grant
    ///
    /// - Throws: CaptureError.permissionDenied if access is not granted
    func requestPermission() async throws {
        AppLogger.capture.debug("Requesting screen capture permission")
        try await services.shareableContent.requestPermission()
        AppLogger.capture.info("Screen capture permission granted")
    }

    /// Updates the list of available windows for capture
    ///
    /// Flow:
    /// 1. Retrieves current window list from system
    /// 2. Applies window filters to exclude invalid targets
    /// 3. Updates available windows property on main actor
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
    /// 1. Validates capture state and window selection
    /// 2. Creates stream configuration for window
    /// 3. Starts capture engine and frame processing
    /// 4. Updates capture state on success
    ///
    /// - Throws:
    ///   - CaptureError.noWindowSelected if no window selected
    ///   - CaptureError.captureStreamFailed for stream initialization failures
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
    /// 1. Validates capture is active
    /// 2. Cancels frame processing task
    /// 3. Stops capture engine stream
    /// 4. Resets capture state
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
    ///
    /// Flow:
    /// 1. Validates window selection exists
    /// 2. Requests window focus through service
    /// 3. Handles edit mode state appropriately
    ///
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
    ///
    /// Flow:
    /// 1. Cancels any existing capture task
    /// 2. Creates new async task for frame processing
    /// 3. Updates captured frame state for each new frame
    /// 4. Handles capture errors through error handler
    ///
    /// - Parameter frameStream: Stream of captured frames from engine
    /// - Important: Must be called on MainActor to ensure state updates
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

    /// Handles errors during capture operations
    ///
    /// Flow:
    /// 1. Logs error with detailed context
    /// 2. Stops active capture session
    /// 3. Updates UI state appropriately
    ///
    /// - Parameter error: The error that occurred during capture
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
    /// 1. Creates unique observer identifier
    /// 2. Registers focus and title change callbacks
    /// 3. Sets up frame rate change handling
    ///
    /// - Important: Window observer registration must be balanced with removal
    private func setupObservers() {
        AppLogger.capture.debug("Setting up window state observers")

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
    ///
    /// Flow:
    /// 1. Requests focus state from window service
    /// 2. Updates published state property
    /// 3. Logs state change for debugging
    private func updateFocusState() async {
        isSourceWindowFocused = await services.windowFocus.updateFocusState(for: selectedWindow)

        if let window = selectedWindow {
            AppLogger.windows.debug(
                "Window focus state updated: '\(window.title ?? "untitled")' focused: \(isSourceWindowFocused)"
            )
        }
    }

    /// Updates title of the source window
    ///
    /// Flow:
    /// 1. Requests updated title from window service
    /// 2. Updates published title property
    /// 3. Logs title changes for tracking
    private func updateWindowTitle() async {
        let oldTitle = windowTitle
        windowTitle = await services.titleService.updateWindowTitle(for: selectedWindow)

        if let newTitle = windowTitle, oldTitle != newTitle {
            AppLogger.windows.debug("Window title updated: '\(newTitle)'")
        }
    }

    /// Updates capture configuration when settings change
    ///
    /// Flow:
    /// 1. Validates capture is active with selected window
    /// 2. Creates new configuration with updated settings
    /// 3. Applies configuration to active stream
    ///
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

// MARK: - Error Types

/// Error cases that can occur during window capture operations
enum CaptureError: LocalizedError {
    /// Screen recording permission was denied by user or system
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
