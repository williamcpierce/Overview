/*
 CaptureServices.swift
 Overview

 Created by William Pierce on 12/6/24.

 Provides core services for window capture operations, handling stream configuration,
 window filtering, focus management, and state observation. These services form the
 foundation for Overview's window capture capabilities.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import ScreenCaptureKit

// MARK: - Stream Configuration Service

/// Manages stream configuration and optimization for window capture sessions
///
/// Key responsibilities:
/// - Creates and updates stream configurations based on window properties
/// - Manages frame rate and content filter settings
/// - Ensures optimal capture quality across different window types
/// - Handles dynamic configuration updates during capture
///
/// Coordinates with:
/// - CaptureEngine: Provides configuration for capture stream initialization
/// - AppSettings: Receives frame rate and quality preferences
/// - CaptureManager: Coordinates stream updates during active capture
/// - PreviewAccessor: Aligns capture dimensions with preview window scaling
class StreamConfigurationService {
    // MARK: - Properties

    /// Logger for stream configuration operations
    private let logger = AppLogger.capture

    // MARK: - Public Methods

    /// Creates a new stream configuration and content filter for window capture
    ///
    /// Flow:
    /// 1. Configures stream dimensions matching source window
    /// 2. Applies frame timing based on requested rate
    /// 3. Optimizes queue depth for smooth playback
    /// 4. Creates content filter for precise window bounds
    ///
    /// - Parameters:
    ///   - window: Target window to capture
    ///   - frameRate: Desired capture frequency in frames per second
    /// - Returns: Tuple containing stream configuration and content filter
    ///
    /// - Warning: Frame rate changes require full stream reconfiguration
    func createConfiguration(_ window: SCWindow, frameRate: Double) -> (
        SCStreamConfiguration, SCContentFilter
    ) {
        logger.debug(
            "Creating configuration for window: '\(window.title ?? "unknown")', frameRate: \(frameRate)"
        )

        let config = SCStreamConfiguration()

        // Context: Match stream resolution to window for optimal quality
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)

        // Context: Frame interval controls capture rate and resource usage
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))

        // Context: Queue depth of 3 balances latency and smooth playback
        config.queueDepth = 3

        // Context: Cursor adds visual noise to previews
        config.showsCursor = false

        let filter = SCContentFilter(desktopIndependentWindow: window)
        return (config, filter)
    }

    /// Updates an existing stream's configuration while maintaining capture
    ///
    /// Flow:
    /// 1. Generates new configuration with current settings
    /// 2. Updates stream configuration atomically
    /// 3. Updates content filter to maintain window tracking
    /// 4. Validates successful application of changes
    ///
    /// - Parameters:
    ///   - stream: Active capture stream to update
    ///   - window: Current target window
    ///   - frameRate: Desired capture frequency
    ///
    /// - Throws: SCStream configuration or filter update errors
    ///
    /// - Warning: Configuration updates may cause momentary frame drops
    /// - Warning: Order matters - config must be updated before filter
    func updateConfiguration(_ stream: SCStream?, _ window: SCWindow, frameRate: Double)
        async throws
    {
        logger.debug("Updating stream configuration: frameRate=\(frameRate)")

        guard let stream = stream else {
            logger.warning("Cannot update configuration: stream is nil")
            return
        }

        let (config, filter) = createConfiguration(window, frameRate: frameRate)

        do {
            try await stream.updateConfiguration(config)
            try await stream.updateContentFilter(filter)
            logger.info("Stream configuration updated successfully")
        } catch {
            logger.error("Failed to update stream configuration: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Window Filter Service

/// Filters and validates windows for capture compatibility
///
/// Key responsibilities:
/// - Filters system windows and invalid capture targets
/// - Validates window properties for capture suitability
/// - Maintains excluded application list
/// - Ensures stable window selection options
///
/// Coordinates with:
/// - ShareableContentService: Processes raw window listings
/// - CaptureManager: Provides filtered window list for capture
/// - SelectionView: Uses filtered windows in selection UI
/// - PreviewAccessor: Validates preview window properties for capture
class WindowFilterService {
    // MARK: - Properties

    /// Logger for window filtering operations
    private let logger = AppLogger.windows

    /// System applications excluded from capture selection
    /// - Note: Critical system UI elements that shouldn't be captured
    private let systemAppBundleIDs = [
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
    ]

    // MARK: - Public Methods

    /// Filters window list to show only valid capture targets
    ///
    /// Flow:
    /// 1. Applies basic window validation (size, visibility)
    /// 2. Removes system windows and UI elements
    /// 3. Filters out Overview's own windows
    /// 4. Validates remaining windows meet capture requirements
    ///
    /// - Parameter windows: Raw list of available windows
    /// - Returns: Filtered list of valid capture targets
    ///
    /// - Note: Changes to system UI may require filter updates
    func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        logger.debug("Filtering \(windows.count) windows")

        let filtered = windows.filter { window in
            isValidBasicWindow(window) && isNotSystemWindow(window)
        }

        logger.info("Found \(filtered.count) valid capture targets")
        return filtered
    }

    // MARK: - Private Methods

    /// Validates fundamental window properties for capture
    ///
    /// Flow:
    /// 1. Checks window dimensions meet minimum size
    /// 2. Validates window has proper title and layer
    /// 3. Ensures window isn't an Overview window
    ///
    /// - Parameter window: Window to validate
    /// - Returns: Whether window meets basic requirements
    private func isValidBasicWindow(_ window: SCWindow) -> Bool {
        // Context: These requirements ensure stable capture and display
        let isValid =
            window.isOnScreen
            && window.frame.height > 100
            && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            && window.windowLayer == 0
            && window.title != nil
            && !window.title!.isEmpty

        if !isValid {
            logger.debug("Window validation failed: '\(window.title ?? "unknown")'")
        }

        return isValid
    }

    /// Checks if window belongs to excludable system service
    ///
    /// Flow:
    /// 1. Filters desktop window
    /// 2. Removes system UI server windows
    /// 3. Excludes other system applications
    ///
    /// - Parameter window: Window to check
    /// - Returns: Whether window should be included
    private func isNotSystemWindow(_ window: SCWindow) -> Bool {
        // Context: Desktop window requires special handling
        let isNotDesktop =
            window.owningApplication?.bundleIdentifier != "com.apple.finder"
            || window.title != "Desktop"

        // Context: System UI windows could cause capture feedback
        let isNotSystemUIServer =
            window.owningApplication?.bundleIdentifier != "com.apple.systemuiserver"

        // Context: Other system apps might expose sensitive UI
        let isNotSystemApp = !systemAppBundleIDs.contains(
            window.owningApplication?.bundleIdentifier ?? "")

        let isNotSystem = isNotDesktop && isNotSystemUIServer && isNotSystemApp

        if !isNotSystem {
            logger.debug("Excluding system window: '\(window.title ?? "unknown")'")
        }

        return isNotSystem
    }
}

// MARK: - Window Focus Service

/// Manages window focus state and activation while coordinating with system window manager
///
/// Key responsibilities:
/// - Handles window activation requests safely
/// - Tracks focus state of captured windows
/// - Prevents focus changes during edit mode
/// - Maintains window activation history
///
/// Coordinates with:
/// - CaptureManager: Provides window focus state updates
/// - NSWorkspace: Monitors active application changes
/// - InteractionOverlay: Triggers focus state transitions
/// - PreviewView: Updates visual state based on focus
/// - PreviewAccessor: Coordinates preview window level changes during focus
class WindowFocusService {
    // MARK: - Properties

    /// Logger for window focus operations
    private let logger = AppLogger.windows

    // MARK: - Public Methods

    /// Activates the captured window's application when appropriate
    ///
    /// Flow:
    /// 1. Validates edit mode state to prevent accidental activation
    /// 2. Retrieves owning application process ID
    /// 3. Requests application activation via workspace
    /// 4. Verifies activation success
    ///
    /// - Parameters:
    ///   - window: Window to activate
    ///   - isEditModeEnabled: Current edit mode state
    ///
    /// - Warning: Must check edit mode to prevent unwanted activation
    /// - Warning: Application activation may fail if app is unresponsive
    func focusWindow(window: SCWindow, isEditModeEnabled: Bool) {
        // Context: Edit mode prevents accidental window switching
        guard !isEditModeEnabled,
            let processID = window.owningApplication?.processID
        else {
            logger.warning(
                "Cannot focus window: editMode=\(isEditModeEnabled), processID=\(window.owningApplication?.processID ?? 0)"
            )
            return
        }

        logger.info("Focusing window: '\(window.title ?? "unknown")', processID=\(processID)")

        let success =
            NSRunningApplication(processIdentifier: pid_t(processID))?
            .activate() ?? false

        if !success {
            logger.error("Failed to activate window: processID=\(processID)")
        }
    }

    /// Determines if specified window's application currently has focus
    ///
    /// Flow:
    /// 1. Validates window and application references
    /// 2. Retrieves current frontmost application
    /// 3. Compares process IDs for focus state
    /// 4. Updates focus tracking state
    ///
    /// - Parameter window: Window to check focus state
    /// - Returns: Whether window's application is frontmost
    ///
    /// - Note: Uses process ID comparison for reliable state tracking
    func updateFocusState(for window: SCWindow?) async -> Bool {
        guard let window = window,
            let activeApp = NSWorkspace.shared.frontmostApplication,
            let selectedApp = window.owningApplication
        else {
            logger.debug("Cannot determine focus state: window or app references missing")
            return false
        }

        // Context: Process ID comparison handles app bundles correctly
        let isFocused = activeApp.processIdentifier == selectedApp.processID
        logger.debug("Window focus state: '\(window.title ?? "unknown")', focused=\(isFocused)")
        return isFocused
    }
}

// MARK: - Window Title Service

/// Manages window title updates and state tracking across capture sessions
///
/// Key responsibilities:
/// - Updates window titles as they change
/// - Maintains current window title state
/// - Handles title retrieval errors
/// - Ensures consistent title display
///
/// Coordinates with:
/// - CaptureManager: Provides current window title state
/// - SCShareableContent: Retrieves updated window information
/// - PreviewView: Displays current window titles
/// - SelectionView: Shows window titles in selection UI
/// - PreviewAccessor: Updates preview window chrome with titles
class WindowTitleService {
    // MARK: - Properties

    /// Logger for title update operations
    private let logger = AppLogger.windows

    // MARK: - Public Methods

    /// Updates the title for a captured window by finding current state
    ///
    /// Flow:
    /// 1. Retrieves current shareable content
    /// 2. Matches window using process ID and frame
    /// 3. Updates title state if match found
    /// 4. Handles errors without disrupting capture
    ///
    /// - Parameter window: Window to update title for
    /// - Returns: Current window title or nil if not found
    ///
    /// - Warning: Title updates may fail if window is minimized
    /// - Note: Uses frame matching to handle multiple windows from same app
    func updateWindowTitle(for window: SCWindow?) async -> String? {
        guard let window = window else {
            logger.debug("Cannot update title: window reference is nil")
            return nil
        }

        do {
            // Context: Exclude desktop to prevent false matches
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)

            // Context: Match both process and frame to handle multiple windows
            let title = content.windows.first { updatedWindow in
                updatedWindow.owningApplication?.processID == window.owningApplication?.processID
                    && updatedWindow.frame == window.frame
            }?.title

            if title != nil {
                logger.debug("Updated window title: '\(title!)'")
            } else {
                logger.warning("Failed to find matching window for title update")
            }

            return title
        } catch {
            logger.error("Failed to update window title: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Window Observer Service

/// Observes window state changes and notifies interested components
///
/// Key responsibilities:
/// - Monitors window focus changes
/// - Tracks window title updates
/// - Manages notification observer lifecycle
/// - Coordinates state updates across components
///
/// Coordinates with:
/// - NSWorkspace: Monitors application activation
/// - NotificationCenter: Observes window state changes
/// - CaptureManager: Notifies of window state updates
/// - WindowFocusService: Updates focus state on changes
/// - WindowTitleService: Triggers title updates
class WindowObserverService {
    // MARK: - Properties

    /// Logger for window observation operations
    private let logger = AppLogger.windows

    /// Callback triggered when window focus changes
    /// - Note: Async to prevent blocking during updates
    var onFocusStateChanged: (() async -> Void)?

    /// Callback triggered when window title changes
    /// - Note: Async to handle title lookup delays
    var onWindowTitleChanged: (() async -> Void)?

    // Context: Strong references prevent premature deallocation
    private var workspaceObserver: NSObjectProtocol?
    private var windowObserver: NSObjectProtocol?
    private var titleCheckTimer: Timer?

    // MARK: - Lifecycle

    deinit {
        stopObserving()
    }

    // MARK: - Public Methods

    /// Initializes window state observation and periodic checks
    ///
    /// Flow:
    /// 1. Sets up workspace activation monitoring
    /// 2. Configures window focus observers
    /// 3. Initiates periodic title checks
    /// 4. Validates observer registration
    ///
    /// - Warning: Must be balanced with stopObserving call
    /// - Note: Title checks run every second to catch manual changes
    func startObserving() {
        logger.info("Starting window state observation")
        setupWorkspaceObserver()
        setupWindowObserver()
        startTitleChecks()
    }

    /// Stops observation and cleans up system resources
    ///
    /// Flow:
    /// 1. Removes workspace notification observers
    /// 2. Removes window notification observers
    /// 3. Invalidates title check timer
    /// 4. Cleans up observer references
    ///
    /// - Warning: Must be called before service deallocation
    func stopObserving() {
        logger.info("Stopping window state observation")

        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        titleCheckTimer?.invalidate()
    }

    // MARK: - Private Methods

    /// Configures workspace activation monitoring
    ///
    /// Flow:
    /// 1. Creates notification observer
    /// 2. Registers for activation events
    /// 3. Sets up async callback handling
    private func setupWorkspaceObserver() {
        logger.debug("Setting up workspace observer")

        // Context: Workspace notifications catch app-level focus changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.onFocusStateChanged?()
            }
        }
    }

    /// Sets up window focus change monitoring
    ///
    /// Flow:
    /// 1. Creates notification observer
    /// 2. Registers for window focus events
    /// 3. Configures async state updates
    private func setupWindowObserver() {
        logger.debug("Setting up window focus observer")

        // Context: Window notifications catch window-level focus changes
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.onFocusStateChanged?()
            }
        }
    }

    /// Initiates periodic window title verification
    ///
    /// Flow:
    /// 1. Invalidates existing timer
    /// 2. Creates new check timer
    /// 3. Configures async title updates
    ///
    /// - Warning: Timer retained by RunLoop until invalidated
    /// - Note: One second interval balances updates and performance
    private func startTitleChecks() {
        titleCheckTimer?.invalidate()

        logger.debug("Starting periodic title checks")

        // Context: Regular checks catch title changes that don't trigger events
        titleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { [weak self] in
                await self?.onWindowTitleChanged?()
            }
        }
    }
}

// MARK: - Shareable Content Service

/// Manages screen capture permissions and window availability state
///
/// Key responsibilities:
/// - Handles screen capture permission requests
/// - Retrieves available windows for capture
/// - Manages system permission state
/// - Provides window listing updates
///
/// Coordinates with:
/// - SCShareableContent: Interfaces with system screen capture
/// - CaptureManager: Provides available windows for capture
/// - SelectionView: Uses window list for UI presentation
/// - WindowFilterService: Receives raw window list for filtering
class ShareableContentService {
    // MARK: - Properties

    /// Logger for content access operations
    private let logger = AppLogger.capture

    // MARK: - Public Methods

    /// Requests screen capture permission through system dialog
    ///
    /// Flow:
    /// 1. Attempts to access shareable content
    /// 2. Triggers system permission dialog if needed
    /// 3. Validates permission grant
    /// 4. Handles permission denial gracefully
    ///
    /// - Throws: CaptureError.permissionDenied or system API errors
    ///
    /// - Warning: May trigger system permission dialog
    /// - Note: Permission persists across app launches
    func requestPermission() async throws {
        logger.info("Requesting screen capture permission")
        do {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            logger.info("Screen capture permission granted")
        } catch {
            logger.error("Screen capture permission denied: \(error.localizedDescription)")
            throw CaptureError.permissionDenied
        }
    }

    /// Retrieves current list of windows available for capture
    ///
    /// Flow:
    /// 1. Validates capture permission
    /// 2. Requests current shareable content
    /// 3. Returns complete window list for filtering
    /// 4. Handles permission and API errors
    ///
    /// - Returns: Array of available windows
    /// - Throws: Permission or system API errors
    ///
    /// - Warning: May fail if permission not granted
    /// - Note: Includes off-screen windows for complete listing
    func getAvailableWindows() async throws -> [SCWindow] {
        logger.debug("Retrieving available windows")
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)
            logger.info("Found \(content.windows.count) total windows")
            return content.windows
        } catch {
            logger.error("Failed to get available windows: \(error.localizedDescription)")
            throw error
        }
    }
}
