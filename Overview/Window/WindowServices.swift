/*
 WindowServices.swift
 Overview

 Created by William Pierce on 12/15/24.

 Provides a service-oriented architecture for window management, offering a set of
 specialized services for window filtering, focusing, title tracking, and state
 observation through a centralized singleton container.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import ScreenCaptureKit

// MARK: - Window Services Container

/// Centralized container managing core window-related service lifecycle and access
///
/// Key responsibilities:
/// - Provides singleton access to window management services
/// - Ensures proper service initialization order
/// - Maintains service lifecycle consistency
/// - Coordinates cross-service operations
///
/// Coordinates with:
/// - CaptureManager: Window capture and management operations
/// - PreviewView: Window display and user interactions
/// - HotkeyManager: Keyboard shortcut processing
/// - WindowManager: Global window state coordination
/// - WindowObserver: Window state change notifications
@MainActor
final class WindowServices {
    // MARK: - Properties

    /// Shared instance for app-wide service access
    static let shared = WindowServices()

    /// Core service instances shared across components
    let windowFilter = WindowFilterService()
    let windowFocus = WindowFocusService()
    let titleService = WindowTitleService()
    let windowObserver = WindowObserverService()
    let shareableContent = ShareableContentService()

    // MARK: - Initialization

    private init() {
        AppLogger.windows.info("Initializing window services container")
    }
}

// MARK: - Window Filter Service

/// Validates and filters windows for capture compatibility
///
/// Key responsibilities:
/// - Applies window capture eligibility rules
/// - Filters system UI components and utilities
/// - Maintains excluded application list
/// - Validates window metadata integrity
///
/// Coordinates with:
/// - ShareableContent: Raw window list provider
/// - CaptureManager: Filtered window consumer
/// - WindowManager: Window state tracking
/// - WindowObserver: Window updates handling
final class WindowFilterService {
    // MARK: - Properties

    /// Category-specific logger instance
    private let logger = AppLogger.windows

    /// System applications excluded from capture selection
    /// - Note: Prevents interference with critical system UI
    private let systemAppBundleIDs = [
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
    ]

    // MARK: - Public Methods

    /// Filters window list to identify valid capture targets
    ///
    /// Flow:
    /// 1. Applies basic window property validation
    /// 2. Filters out system windows and components
    /// 3. Updates filtering statistics
    ///
    /// - Parameter windows: Raw list of available windows
    /// - Returns: Filtered list of valid capture targets
    func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        logger.debug("Starting window filtering: total=\(windows.count)")

        let filtered = windows.filter { window in
            isValidBasicWindow(window) && isNotSystemWindow(window)
        }

        logger.info(
            "Window filtering complete: valid=\(filtered.count), filtered=\(windows.count - filtered.count)"
        )
        return filtered
    }

    // MARK: - Private Methods

    /// Validates basic window properties for capture compatibility
    ///
    /// Flow:
    /// 1. Checks visibility and dimension requirements
    /// 2. Validates window metadata completeness
    /// 3. Enforces window layer restrictions
    ///
    /// - Parameter window: Window to validate
    /// - Returns: Whether window meets basic requirements
    private func isValidBasicWindow(_ window: SCWindow) -> Bool {
        let isValid =
            window.isOnScreen
            && window.frame.height > 100
            && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            && window.windowLayer == 0
            && window.title != nil
            && !window.title!.isEmpty

        if !isValid {
            logger.debug(
                "Window failed validation: '\(window.title ?? "untitled")', height=\(window.frame.height), layer=\(window.windowLayer)"
            )
        }

        return isValid
    }

    /// Determines if window belongs to essential system components
    ///
    /// Flow:
    /// 1. Checks desktop window exclusion
    /// 2. Validates against system UI processes
    /// 3. Filters known system applications
    ///
    /// - Parameter window: Window to check
    /// - Returns: Whether window is not a system component
    private func isNotSystemWindow(_ window: SCWindow) -> Bool {
        // Context: Desktop window has special handling requirements
        let isNotDesktop =
            window.owningApplication?.bundleIdentifier != "com.apple.finder"
            || window.title != "Desktop"

        // System UI server hosts critical system components
        let isNotSystemUIServer =
            window.owningApplication?.bundleIdentifier != "com.apple.systemuiserver"

        // Check against known system application list
        let isNotSystemApp = !systemAppBundleIDs.contains(
            window.owningApplication?.bundleIdentifier ?? "")

        let isNotSystem = isNotDesktop && isNotSystemUIServer && isNotSystemApp

        if !isNotSystem {
            logger.debug(
                "Excluding system window: '\(window.title ?? "untitled")', bundleID=\(window.owningApplication?.bundleIdentifier ?? "unknown")"
            )
        }

        return isNotSystem
    }
}

// MARK: - Window Focus Service

/// Manages window activation and focus state tracking
///
/// Key responsibilities:
/// - Processes window focus requests safely
/// - Maintains accurate focus state tracking
/// - Coordinates with window observers
/// - Handles focus-related hotkeys
///
/// Coordinates with:
/// - CaptureManager: Focus request handling
/// - WindowObserver: Focus state updates
/// - PreviewView: Focus state display
/// - HotkeyService: Shortcut processing
final class WindowFocusService {
    // MARK: - Properties

    /// Category-specific logger instance
    private let logger = AppLogger.windows

    // MARK: - Public Methods

    /// Attempts to focus specified window with edit mode safety
    ///
    /// Flow:
    /// 1. Validates edit mode and process state
    /// 2. Activates target application
    /// 3. Updates window focus tracking
    ///
    /// - Parameters:
    ///   - window: Target window to focus
    ///   - isEditModeEnabled: Current edit mode state
    /// - Important: Operation blocked during edit mode
    func focusWindow(window: SCWindow, isEditModeEnabled: Bool) {
        guard !isEditModeEnabled,
            let processID = window.owningApplication?.processID
        else {
            logger.warning(
                "Focus request blocked: editMode=\(isEditModeEnabled), processID=\(window.owningApplication?.processID ?? 0)"
            )
            return
        }

        logger.debug("Focusing window: '\(window.title ?? "untitled")', processID=\(processID)")

        // Context: Window activation requires direct process focus
        let success = activateTargetProcess(processID)

        if success {
            logger.info("Window successfully focused: '\(window.title ?? "untitled")'")
        } else {
            logger.error("Window focus failed: processID=\(processID)")
        }
    }

    /// Focuses window by title with Overview activation handling
    ///
    /// Flow:
    /// 1. Locates target application
    /// 2. Activates Overview briefly
    /// 3. Focuses target window
    ///
    /// - Parameter title: Title of window to focus
    /// - Returns: Whether focus operation succeeded
    @MainActor
    func focusWindow(withTitle title: String) -> Bool {
        logger.debug("Processing title-based focus request: '\(title)'")

        guard let runningApp = findApplicationByWindowTitle(title) else {
            logger.warning("No application found for window: '\(title)'")
            return false
        }

        // Context: Brief Overview focus ensures reliable activation
        NSApp.activate(ignoringOtherApps: true)

        let success = runningApp.activate()

        if success {
            logger.info("Title-based focus successful: '\(title)'")
        } else {
            logger.error("Title-based focus failed: '\(title)'")
        }

        return success
    }

    /// Locates application owning window with specified title
    ///
    /// Flow:
    /// 1. Retrieves complete window list
    /// 2. Matches window by exact title
    /// 3. Maps to running application
    ///
    /// - Parameter title: Window title to locate
    /// - Returns: Running application if found
    private func findApplicationByWindowTitle(_ title: String) -> NSRunningApplication? {
        let options = CGWindowListOption(arrayLiteral: .optionAll)
        let windowList =
            CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] ?? []

        logger.debug("Searching \(windowList.count) windows for title match: '\(title)'")

        // Find window and extract owning process ID
        guard
            let windowInfo = windowList.first(where: { info in
                guard let windowTitle = info[kCGWindowName] as? String,
                    !windowTitle.isEmpty
                else { return false }
                return windowTitle == title
            }), let windowPID = windowInfo[kCGWindowOwnerPID] as? pid_t
        else {
            logger.warning("No matching window found: '\(title)'")
            return nil
        }

        // Map process ID to running application
        let runningApp = NSWorkspace.shared.runningApplications.first { app in
            app.processIdentifier == windowPID
        }

        if let app = runningApp {
            logger.debug("Found application: '\(app.localizedName ?? "unknown")', pid=\(windowPID)")
        } else {
            logger.warning("No running application for pid=\(windowPID)")
        }

        return runningApp
    }

    /// Activates application process by identifier
    ///
    /// - Parameter processID: Target process identifier
    /// - Returns: Whether activation succeeded
    private func activateTargetProcess(_ processID: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: processID) else {
            logger.error("Invalid process ID: \(processID)")
            return false
        }

        return app.activate()
    }

    /// Updates focus state for specified window
    ///
    /// Flow:
    /// 1. Validates window and application state
    /// 2. Compares process identifiers
    /// 3. Updates tracking state
    ///
    /// - Parameter window: Window to check
    /// - Returns: Whether window's application is active
    func updateFocusState(for window: SCWindow?) async -> Bool {
        guard let window = window,
            let activeApp = NSWorkspace.shared.frontmostApplication,
            let selectedApp = window.owningApplication
        else {
            logger.debug("Focus state check failed: missing window or app reference")
            return false
        }

        let isFocused = activeApp.processIdentifier == selectedApp.processID

        if isFocused {
            logger.debug("Window is focused: '\(window.title ?? "untitled")'")
        }

        return isFocused
    }
}

// MARK: - Window Title Service

/// Updates and tracks window title state changes
///
/// Key responsibilities:
/// - Handles title state updates
/// - Validates title availability
/// - Coordinates with window observer
/// - Updates UI components
///
/// Coordinates with:
/// - WindowObserver: Title change events
/// - CaptureManager: Title state access
/// - PreviewView: Title display updates
final class WindowTitleService {
    // MARK: - Properties

    /// Category-specific logger instance
    private let logger = AppLogger.windows

    // MARK: - Public Methods

    /// Updates title for specified window
    ///
    /// Flow:
    /// 1. Validates window reference
    /// 2. Retrieves current state
    /// 3. Matches window by properties
    ///
    /// - Parameter window: Window to update
    /// - Returns: Current window title if available
    func updateWindowTitle(for window: SCWindow?) async -> String? {
        guard let window = window else {
            logger.debug("Title update skipped: nil window reference")
            return nil
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)

            let title = content.windows.first { updatedWindow in
                updatedWindow.owningApplication?.processID == window.owningApplication?.processID
                    && updatedWindow.frame == window.frame
            }?.title

            if let title = title {
                logger.debug("Title updated: '\(title)'")
            } else {
                logger.warning("No matching window found for title update")
            }

            return title
        } catch {
            logger.error("Title update failed: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Window Observer Service

/// Manages window state change observation and notifications
///
/// Key responsibilities:
/// - Tracks focus state changes
/// - Monitors title updates
/// - Manages observer lifecycle
/// - Coordinates callbacks
///
/// Coordinates with:
/// - CaptureManager: State update registration
/// - WindowFocus: Focus state changes
/// - WindowTitle: Title updates
/// - PreviewView: State display
final class WindowObserverService {
    // MARK: - Properties

    /// Category-specific logger instance
    private let logger = AppLogger.windows

    /// Registered observer callbacks
    private var focusObservers: [UUID: () async -> Void] = [:]
    private var titleObservers: [UUID: () async -> Void] = [:]

    /// System notification observers
    private var workspaceObserver: NSObjectProtocol?
    private var windowObserver: NSObjectProtocol?

    /// Timer for periodic title checks
    private var titleCheckTimer: Timer?

    // MARK: - Lifecycle

    deinit {
        stopObserving()
    }

    // MARK: - Public Methods

    /// Registers window state observer
    ///
    /// Flow:
    /// 1. Stores callback references
    /// 2. Initializes observation
    /// 3. Configures notifications
    ///
    /// - Parameters:
    ///   - id: Observer identifier
    ///   - onFocusChanged: Focus callback
    ///   - onTitleChanged: Title callback
    func addObserver(
        id: UUID,
        onFocusChanged: @escaping () async -> Void,
        onTitleChanged: @escaping () async -> Void
    ) {
        logger.debug("Adding state observer: \(id)")

        focusObservers[id] = onFocusChanged
        titleObservers[id] = onTitleChanged

        if focusObservers.count == 1 {
            startObserving()
        }
    }

    /// Removes registered observer
    ///
    /// Flow:
    /// 1. Removes callbacks
    /// 2. Stops observation if last
    /// 3. Cleans up resources
    ///
    /// - Parameter id: Observer identifier to remove
    func removeObserver(id: UUID) {
        logger.debug("Removing state observer: \(id)")
        focusObservers.removeValue(forKey: id)
        titleObservers.removeValue(forKey: id)

        if focusObservers.isEmpty {
            stopObserving()
        }
    }

    // MARK: - Private Methods

    /// Initializes observation system
    ///
    /// Flow:
    /// 1. Sets up workspace observer
    /// 2. Configures window tracking
    /// 3. Starts title monitoring
    private func startObserving() {
        logger.info("Starting window state observation")
        setupWorkspaceObserver()
        setupWindowObserver()
        startTitleChecks()
    }

    /// Stops observation and cleans up
    ///
    /// Flow:
    /// 1. Removes notification observers
    /// 2. Stops title timer
    /// 3. Cleans up state
    private func stopObserving() {
        logger.info("Stopping window state observation")

        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        titleCheckTimer?.invalidate()
    }

    /// Configures workspace-level observer
    ///
    /// Flow:
    /// 1. Sets up notification handler
    /// 2. Configures callback dispatch
    /// 3. Maintains weak references
    private func setupWorkspaceObserver() {
        logger.debug("Configuring workspace observer")

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.focusObservers else { return }
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }

    /// Sets up window-level observer
    ///
    /// Flow:
    /// 1. Configures notification tracking
    /// 2. Sets up callback handling
    /// 3. Maintains memory safety
    private func setupWindowObserver() {
        logger.debug("Configuring window observer")

        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.focusObservers else { return }
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }

    /// Initializes periodic title monitoring
    ///
    /// Flow:
    /// 1. Creates timer with interval
    /// 2. Configures callback dispatch
    /// 3. Maintains weak references
    private func startTitleChecks() {
        titleCheckTimer?.invalidate()

        logger.debug("Starting title check timer")

        // Context: 1-second interval balances updates and performance
        titleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.titleObservers else { return }
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }
}

// MARK: - Shareable Content Service

/// Manages screen recording permissions and window access
///
/// Key responsibilities:
/// - Handles permission requests and validation
/// - Provides window list access
/// - Maintains consistent access state
/// - Coordinates with system privacy
///
/// Coordinates with:
/// - CaptureManager: Permission handling
/// - SelectionView: Window list access
/// - WindowFilter: List filtering
/// - WindowManager: State tracking
final class ShareableContentService {
    // MARK: - Properties

    /// Category-specific logger instance
    private let logger = AppLogger.capture

    // MARK: - Public Methods

    /// Requests screen recording permission
    ///
    /// Flow:
    /// 1. Validates system access
    /// 2. Handles permission response
    /// 3. Updates access state
    ///
    /// - Throws: CaptureError if permission denied
    /// - Important: Required before capture operations
    func requestPermission() async throws {
        logger.info("Requesting screen recording permission")

        do {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            logger.info("Screen recording permission granted")
        } catch {
            logger.error("Screen recording permission denied: \(error.localizedDescription)")
            throw CaptureError.permissionDenied
        }
    }

    /// Retrieves available windows list
    ///
    /// Flow:
    /// 1. Validates permissions
    /// 2. Queries window list
    /// 3. Handles access errors
    ///
    /// - Returns: Array of available windows
    /// - Throws: System errors during retrieval
    func getAvailableWindows() async throws -> [SCWindow] {
        logger.debug("Fetching available windows")

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)

            logger.info("Retrieved \(content.windows.count) available windows")
            return content.windows
        } catch {
            logger.error("Failed to get windows: \(error.localizedDescription)")
            throw error
        }
    }
}
