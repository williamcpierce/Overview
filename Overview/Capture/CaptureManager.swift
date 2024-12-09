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
import OSLog
import ScreenCaptureKit

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
    @Published var selectedWindow: SCWindow? {
        didSet {
            windowTitle = selectedWindow?.title
            Task { await updateFocusState() }
        }
    }

    // MARK: - Private Properties

    /// System logger for capture operations
    private let logger = Logger(subsystem: "com.Overview.CaptureManager", category: "ScreenCapture")

    /// Active Combine subscriptions for cleanup
    private var cancellables = Set<AnyCancellable>()

    /// Current capture operation
    /// - Warning: Must be cancelled before starting new capture
    private var captureTask: Task<Void, Never>?

    // MARK: - Service Dependencies

    /// User-configured settings for capture behavior
    private let appSettings: AppSettings

    /// Low-level screen capture operations
    private let captureEngine: CaptureEngine

    /// Capture stream parameters
    private let streamConfig: StreamConfigurationService

    /// Window filtering for capture targets
    private let windowFilter: WindowFilterService

    /// Window focus state tracking
    private let windowFocus: WindowFocusService

    /// Window title updates
    private let titleService: WindowTitleService

    /// Window state change monitoring
    private let windowObserver: WindowObserverService

    /// Screen recording permissions
    private let shareableContent: ShareableContentService
    
    private let hotkeyService = HotkeyService.shared

    // MARK: - Initialization

    /// Creates capture manager with required services
    ///
    /// Flow:
    /// 1. Stores service dependencies
    /// 2. Sets up window state observers
    /// 3. Configures frame rate monitoring
    ///
    /// - Parameters:
    ///   - appSettings: User preferences
    ///   - services: Optional service overrides for testing
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
        HotkeyService.shared.registerFocusCallback(owner: self) { [weak self] windowTitle in
                self?.focusWindowByTitle(windowTitle)
            }
        setupObservers()
    }
    
    deinit {
        // Remove callback registration
        HotkeyService.shared.removeFocusCallback(for: self)
    }

    // MARK: - Public Methods

    /// Requests screen capture permission from the system
    /// - Throws: CaptureError.permissionDenied if access is not granted
    func requestPermission() async throws {
        try await shareableContent.requestPermission()
    }

    /// Updates the list of available windows for capture
    ///
    /// Flow:
    /// 1. Retrieves current window list
    /// 2. Filters out invalid capture targets
    /// 3. Updates available windows property
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
    /// 1. Validates window selection and state
    /// 2. Creates stream configuration
    /// 3. Starts capture engine
    ///
    /// - Throws:
    ///   - CaptureError.noWindowSelected if no window selected
    ///   - CaptureError.captureStreamFailed for initialization failures
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
    ///
    /// Flow:
    /// 1. Cancels active capture task
    /// 2. Stops capture engine
    /// 3. Resets capture state
    func stopCapture() async {
        guard isCapturing else { return }

        captureTask?.cancel()
        captureTask = nil
        await captureEngine.stopCapture()

        isCapturing = false
        capturedFrame = nil
    }

    /// Brings source window to front when preview is clicked
    /// - Parameter isEditModeEnabled: Whether edit mode is active
    func focusWindow(isEditModeEnabled: Bool) {
        guard let window = selectedWindow else { return }
        windowFocus.focusWindow(window: window, isEditModeEnabled: isEditModeEnabled)
    }

    // MARK: - Private Methods

    /// Starts new capture task for processing frames
    /// - Parameter frameStream: Stream of captured frames from engine
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
    ///
    /// Flow:
    /// 1. Logs error details
    /// 2. Stops capture session
    /// 3. Updates UI state
    private func handleCaptureError(_ error: Error) async {
        logger.error("Capture error: \(error.localizedDescription)")
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
        windowObserver.onFocusStateChanged = { [weak self] in
            await self?.updateFocusState()
        }

        windowObserver.onWindowTitleChanged = { [weak self] in
            await self?.updateWindowTitle()
        }

        windowObserver.startObserving()

        // WARNING: Frame rate changes require stream reconfiguration
        appSettings.$frameRate
            .dropFirst()
            .sink { [weak self] _ in
                Task {
                    await self?.updateStreamConfiguration()
                }
            }
            .store(in: &cancellables)
        
        appSettings.$hotkeyBindings
            .sink { [weak self] bindings in
                self?.hotkeyService.registerHotkeys(bindings)
            }
            .store(in: &cancellables)
    }

    /// Updates focus state of the source window
    private func updateFocusState() async {
        isSourceWindowFocused = await windowFocus.updateFocusState(for: selectedWindow)
    }

    /// Updates title of the source window
    private func updateWindowTitle() async {
        windowTitle = await titleService.updateWindowTitle(for: selectedWindow)
    }

    /// Updates capture configuration when settings change
    /// - Warning: Frame rate changes require stream reconfiguration
    private func updateStreamConfiguration() async {
        guard isCapturing, let window = selectedWindow else { return }
        try? await streamConfig.updateConfiguration(
            captureEngine.stream, window, frameRate: appSettings.frameRate)
    }
    
    private func focusWindowByTitle(_ title: String) {
        let logger = Logger(subsystem: "com.Overview.CaptureManager", category: "WindowFocus")
        
        logger.info("Attempting to focus window with title: '\(title)'")
        
        guard let selectedWindow = selectedWindow else {
            logger.error("No window selected")
            return
        }
        
        logger.info("Current window title: '\(selectedWindow.title ?? "nil")'")
        
        // Only focus if the titles match
        if selectedWindow.title == title {
            logger.info("Title match found, focusing window")
            windowFocus.focusWindow(window: selectedWindow, isEditModeEnabled: false)
        } else {
            logger.info("Title mismatch - selected: '\(selectedWindow.title ?? "nil")', target: '\(title)'")
        }
    }
}
