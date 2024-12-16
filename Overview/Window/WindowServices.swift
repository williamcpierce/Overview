/*
 WindowServices.swift
 Overview

 Created by William Pierce on 12/15/24.

 Provides a set of shared window management services used across the application,
 implementing a service-oriented architecture that centralizes window-related
 operations and improves performance through singleton service instances.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import ScreenCaptureKit

// MARK: - Window Services Container

/// Provides centralized access to shared window-related services
///
/// Key responsibilities:
/// - Maintains singleton instances of all window services
/// - Ensures consistent service lifecycle management
/// - Provides type-safe access to service implementations
/// - Coordinates cross-service operations
///
/// Coordinates with:
/// - CaptureManager: Primary consumer of window services
/// - PreviewView: Accesses services for window display
/// - HotkeyManager: Uses services for shortcut handling
/// - SettingsView: Configures service behavior
/// - AppLogger: Provides centralized logging capabilities
///
/// Technical Context:
/// - Services are created once at app launch
/// - All service access must occur on MainActor
/// - Services maintain internal state consistency
/// - Cross-service operations handled through container
@MainActor
final class WindowServices {
    // MARK: - Properties

    /// Shared instance for app-wide service access
    static let shared = WindowServices()

    /// Service instances shared across the application
    let windowFilter = WindowFilterService()
    let windowFocus = WindowFocusService()
    let titleService = WindowTitleService()
    let windowObserver = WindowObserverService()
    let shareableContent = ShareableContentService()

    // MARK: - Initialization

    private init() {
        // Private initializer to enforce singleton pattern
        AppLogger.windows.info("WindowServices initialized")
    }
}

// MARK: - Window Filter Service

/// Filters and validates windows for capture compatibility
///
/// Key responsibilities:
/// - Validates window properties for capture eligibility
/// - Filters out system windows and UI components
/// - Maintains list of excluded system applications
/// - Provides debug logging for filter decisions
///
/// Coordinates with:
/// - ShareableContentService: Receives raw window lists for filtering
/// - CaptureManager: Provides filtered window lists for capture
/// - WindowManager: Supplies filtered windows for management
/// - AppSettings: Applies user preferences to filtering logic
/// - WindowObserverService: Coordinates window state updates
final class WindowFilterService {
    // MARK: - Properties

    /// Logger for window filtering operations
    private let logger = AppLogger.windows

    /// System applications excluded from capture selection
    /// - Note: Prevents capture of critical system UI elements
    private let systemAppBundleIDs = [
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
    ]

    // MARK: - Public Methods

    /// Filters window list to show only valid capture targets
    ///
    /// Flow:
    /// 1. Applies basic window validation
    /// 2. Filters out system windows
    /// 3. Logs filtering results
    ///
    /// - Parameter windows: Raw list of all available windows
    /// - Returns: Filtered list of capturable windows
    func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        logger.debug("Filtering \(windows.count) windows")

        let filtered = windows.filter { window in
            isValidBasicWindow(window) && isNotSystemWindow(window)
        }

        logger.info("Found \(filtered.count) valid capture targets")
        return filtered
    }

    // MARK: - Private Methods

    /// Validates basic window properties for capture compatibility
    ///
    /// Flow:
    /// 1. Checks window visibility and dimensions
    /// 2. Validates window metadata
    /// 3. Logs validation failures
    private func isValidBasicWindow(_ window: SCWindow) -> Bool {
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

    /// Checks if window belongs to system UI components
    ///
    /// Flow:
    /// 1. Validates against desktop window
    /// 2. Checks system UI server windows
    /// 3. Filters known system applications
    private func isNotSystemWindow(_ window: SCWindow) -> Bool {
        let isNotDesktop =
            window.owningApplication?.bundleIdentifier != "com.apple.finder"
            || window.title != "Desktop"

        let isNotSystemUIServer =
            window.owningApplication?.bundleIdentifier != "com.apple.systemuiserver"

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

/// Manages window focus state and activation operations
///
/// Key responsibilities:
/// - Handles window focus requests with edit mode safety
/// - Tracks window focus state changes
/// - Provides focus state information to UI layer
/// - Logs focus operations and state transitions
///
/// Coordinates with:
/// - CaptureManager: Processes focus requests and updates state
/// - WindowObserverService: Receives focus state updates
/// - PreviewView: Displays focus state indicators
/// - HotkeyService: Handles keyboard shortcut focus triggers
/// - AppSettings: Applies user focus preferences
final class WindowFocusService {
    // MARK: - Properties

    /// Logger for focus operations and state changes
    private let logger = AppLogger.windows

    // MARK: - Public Methods

    /// Attempts to focus a specific window if edit mode is disabled
    ///
    /// Flow:
    /// 1. Validates edit mode state to prevent accidental focus
    /// 2. Retrieves process information from window metadata
    /// 3. Validates process ID availability and status
    /// 4. Attempts window activation through NSRunningApplication
    /// 5. Handles activation failures with appropriate logging
    /// 6. Updates focus state tracking if successful
    ///
    /// - Parameters:
    ///   - window: Window to bring to front
    ///   - isEditModeEnabled: Current edit mode state
    /// - Important: Operation blocked during edit mode for safety
    /// - Warning: Process activation may fail if application terminated
    func focusWindow(window: SCWindow, isEditModeEnabled: Bool) {
        guard !isEditModeEnabled,
            let processID = window.owningApplication?.processID
        else {
            logger.warning(
                "Cannot focus window: editMode=\(isEditModeEnabled), processID=\(window.owningApplication?.processID ?? 0)"
            )
            return
        }

        logger.info("Focusing window: '\(window.title ?? "unknown")', processID=\(processID)")

        // When clicking preview window, Overview is already focused, so proceed directly
        let success = activateTargetProcess(processID)
        if !success {
            logger.error("Failed to activate window: processID=\(processID)")
        }
    }

    /// Focuses a window by its title, ensuring Overview is briefly focused first
    @MainActor
    func focusWindow(withTitle title: String) -> Bool {
        logger.debug("Focusing window by title: '\(title)'")

        // Step 1: Find target process before activating Overview
        guard let runningApp = findApplicationByWindowTitle(title) else {
            logger.warning("No running application found with window title: '\(title)'")
            return false
        }

        // Step 2: Bring Overview into focus first
        // This is crucial for global hotkey handling
        NSApp.activate(ignoringOtherApps: true)

        // Step 3: Activate target process
        let success = runningApp.activate()

        if success {
            logger.info("Successfully focused window: '\(title)'")
        } else {
            logger.error("Failed to focus window: '\(title)'")
        }

        return success
    }

    /// Finds the running application that owns a window with the given title
    private func findApplicationByWindowTitle(_ title: String) -> NSRunningApplication? {
        // Get window list including minimized and hidden windows
        let options = CGWindowListOption(arrayLiteral: .optionAll)
        let windowList =
            CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] ?? []

        logger.debug("Searching \(windowList.count) windows for title: '\(title)'")

        // Find window with matching title and get its owning PID
        guard
            let windowInfo = windowList.first(where: { info in
                // Skip windows with empty titles
                guard let windowTitle = info[kCGWindowName] as? String,
                    !windowTitle.isEmpty
                else { return false }
                return windowTitle == title
            }), let windowPID = windowInfo[kCGWindowOwnerPID] as? pid_t
        else {
            logger.warning("No window found with title: '\(title)'")
            return nil
        }

        logger.debug("Found window with PID: \(windowPID)")

        // Find running application with matching PID
        let runningApp = NSWorkspace.shared.runningApplications.first { app in
            app.processIdentifier == windowPID
        }

        if runningApp != nil {
            logger.debug("Found matching application: \(runningApp?.localizedName ?? "unknown")")
        } else {
            logger.warning("No running application found for PID: \(windowPID)")
        }

        return runningApp
    }

    /// Activates a target process by its process ID
    private func activateTargetProcess(_ processID: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: processID) else {
            logger.error("Failed to get running application for PID: \(processID)")
            return false
        }

        return app.activate()
    }

    /// Checks if specified window currently has system focus
    ///
    /// Flow:
    /// 1. Validates window references
    /// 2. Compares active application
    /// 3. Updates focus state
    ///
    /// - Parameter window: Window to check focus state
    /// - Returns: Whether window's application is frontmost
    func updateFocusState(for window: SCWindow?) async -> Bool {
        guard let window = window,
            let activeApp = NSWorkspace.shared.frontmostApplication,
            let selectedApp = window.owningApplication
        else {
            logger.debug("Cannot determine focus state: window or app references missing")
            return false
        }

        let isFocused = activeApp.processIdentifier == selectedApp.processID
        logger.debug("Window focus state: '\(window.title ?? "unknown")', focused=\(isFocused)")
        return isFocused
    }
}

// MARK: - Window Title Service

/// Manages window title updates and state tracking
///
/// Key responsibilities:
/// - Updates window titles during state changes
/// - Handles title availability checking
/// - Maintains title state consistency
/// - Provides logging for title operations
///
/// Coordinates with:
/// - WindowObserverService: Triggers title updates
/// - CaptureManager: Provides current titles
/// - PreviewView: Displays window titles
final class WindowTitleService {
    // MARK: - Properties

    /// Logger for title update operations
    private let logger = AppLogger.windows

    // MARK: - Public Methods

    /// Updates the title for a specified window
    ///
    /// Flow:
    /// 1. Validates window reference
    /// 2. Retrieves current window list
    /// 3. Matches window by properties
    /// 4. Updates title state
    ///
    /// - Parameter window: Window to update title for
    /// - Returns: Current window title or nil if unavailable
    func updateWindowTitle(for window: SCWindow?) async -> String? {
        guard let window = window else {
            logger.debug("Cannot update title: window reference is nil")
            return nil
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)

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
/// - Manages focus and title change observation
/// - Coordinates observer registration and cleanup
/// - Maintains observer lifecycle safety
/// - Provides periodic title update checks
///
/// Coordinates with:
/// - CaptureManager: Registers for state updates
/// - WindowFocusService: Provides focus state changes
/// - WindowTitleService: Triggers title updates
final class WindowObserverService {
    // MARK: - Properties

    /// Logger for observation operations
    private let logger = AppLogger.windows

    /// Maps observer identifiers to their callbacks
    private var focusObservers: [UUID: () async -> Void] = [:]
    private var titleObservers: [UUID: () async -> Void] = [:]

    /// System notification observers
    private var workspaceObserver: NSObjectProtocol?
    private var windowObserver: NSObjectProtocol?

    /// Timer for periodic title state checks
    private var titleCheckTimer: Timer?

    // MARK: - Lifecycle

    deinit {
        stopObserving()
    }

    // MARK: - Public Methods

    /// Registers a new observer for window state changes
    ///
    /// Flow:
    /// 1. Stores observer callbacks
    /// 2. Starts observation if first observer
    /// 3. Configures notification handlers
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the observer
    ///   - onFocusChanged: Focus state change callback
    ///   - onTitleChanged: Title change callback
    func addObserver(
        id: UUID,
        onFocusChanged: @escaping () async -> Void,
        onTitleChanged: @escaping () async -> Void
    ) {
        logger.debug("Adding observer: \(id)")
        focusObservers[id] = onFocusChanged
        titleObservers[id] = onTitleChanged

        // Start observing if this is the first observer
        if focusObservers.count == 1 {
            startObserving()
        }
    }

    /// Removes an observer and cleans up if last observer
    ///
    /// Flow:
    /// 1. Removes observer callbacks
    /// 2. Stops observation if no observers remain
    /// 3. Cleans up observation resources
    ///
    /// - Parameter id: Observer identifier to remove
    func removeObserver(id: UUID) {
        logger.debug("Removing observer: \(id)")
        focusObservers.removeValue(forKey: id)
        titleObservers.removeValue(forKey: id)

        // Stop observing if no observers remain
        if focusObservers.isEmpty {
            stopObserving()
        }
    }

    // MARK: - Private Methods

    /// Starts the observation system
    ///
    /// Flow:
    /// 1. Sets up workspace notifications
    /// 2. Configures window observers
    /// 3. Starts title check timer
    private func startObserving() {
        logger.info("Starting window state observation")
        setupWorkspaceObserver()
        setupWindowObserver()
        startTitleChecks()
    }

    /// Stops all observation and cleans up resources
    ///
    /// Flow:
    /// 1. Removes notification observers
    /// 2. Stops title check timer
    /// 3. Cleans up observation state
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

    /// Configures workspace-level notification observation
    private func setupWorkspaceObserver() {
        logger.debug("Setting up workspace observer")

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.focusObservers else { return }
                // Notify all registered focus observers
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }

    /// Configures window-level focus notification observation
    private func setupWindowObserver() {
        logger.debug("Setting up window focus observer")

        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.focusObservers else { return }
                // Notify all registered focus observers
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }

    /// Starts periodic title update checks
    ///
    /// Flow:
    /// 1. Invalidates existing timer
    /// 2. Creates new timer with 1-second interval
    /// 3. Configures observer notifications
    private func startTitleChecks() {
        titleCheckTimer?.invalidate()

        logger.debug("Starting periodic title checks")

        // Context: 1-second interval balances responsiveness and performance
        titleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.titleObservers else { return }
                // Notify all registered title observers
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }
}

// MARK: - Shareable Content Service

/// Manages screen capture permissions and window availability
///
/// Key responsibilities:
/// - Handles screen recording permission requests and validation
/// - Provides access to current window list with error handling
/// - Maintains consistent window access state
/// - Coordinates with system privacy settings
///
/// Coordinates with:
/// - CaptureManager: Provides permission status and window access
/// - SelectionView: Supplies available window list for capture
/// - WindowFilterService: Provides unfiltered window list
/// - AppSettings: Adapts to user privacy preferences
final class ShareableContentService {
    // MARK: - Properties

    /// Logger for screen recording and window access operations
    private let logger = AppLogger.capture

    // MARK: - Public Methods

    /// Requests and validates screen capture permission
    ///
    /// Flow:
    /// 1. Attempts to access screen content API
    /// 2. Validates system permission status
    /// 3. Handles permission response
    /// 4. Updates logging state
    ///
    /// - Throws: CaptureError.permissionDenied if screen recording access is denied
    /// - Important: Must be called before attempting any window capture
    func requestPermission() async throws {
        logger.info("Requesting screen capture permission")

        do {
            // Context: Using excludingDesktopWindows:false to ensure complete window access
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            logger.info("Screen capture permission granted")
        } catch {
            logger.error("Screen capture permission denied: \(error.localizedDescription)")
            throw CaptureError.permissionDenied
        }
    }

    /// Retrieves the current list of available windows
    ///
    /// Flow:
    /// 1. Validates capture permissions
    /// 2. Queries system for window list
    /// 3. Handles access errors
    /// 4. Returns complete window array
    ///
    /// - Returns: Array of all available SCWindow instances
    /// - Throws: System errors during window list retrieval
    /// - Important: Returned windows still need filtering for capture compatibility
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
