/*
 CaptureServices.swift
 Overview

 Created by William Pierce on 12/6/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import OSLog
import ScreenCaptureKit

// MARK: - Stream Configuration Service
/// Manages stream configuration for window capture, handling frame rate and content filter settings
///
/// Key responsibilities:
/// - Creates SCStreamConfiguration instances with appropriate capture parameters
/// - Updates existing stream configurations when capture settings change
///
/// Coordinates with:
/// - CaptureEngine: Provides configuration for capture stream initialization
/// - AppSettings: Uses frame rate settings to configure capture frequency
class StreamConfigurationService {
    /// Creates a new stream configuration and content filter for window capture
    ///
    /// Flow:
    /// 1. Configures stream parameters including dimensions and frame rate
    /// 2. Creates content filter for the specified window
    /// 3. Returns configuration tuple ready for capture initialization
    func createConfiguration(_ window: SCWindow, frameRate: Double) -> (
        SCStreamConfiguration, SCContentFilter
    ) {
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        /// Using minimum queue depth of 3
        config.queueDepth = 3
        config.showsCursor = false

        let filter = SCContentFilter(desktopIndependentWindow: window)
        return (config, filter)
    }

    /// Updates an existing stream's configuration and content filter
    ///
    /// - Throws: Errors from SCStream configuration or filter updates
    func updateConfiguration(_ stream: SCStream?, _ window: SCWindow, frameRate: Double)
        async throws
    {
        guard let stream = stream else { return }
        let (config, filter) = createConfiguration(window, frameRate: frameRate)
        try await stream.updateConfiguration(config)
        try await stream.updateContentFilter(filter)
    }
}

// MARK: - Window Filter Service
/// Filters available windows to show only valid capture targets
///
/// Key responsibilities:
/// - Filters out system windows and invalid capture targets
/// - Validates window properties for capture compatibility
///
/// Coordinates with:
/// - ShareableContentService: Processes raw window list from screen capture API
class WindowFilterService {
    /// System apps that should be excluded from capture
    private let systemAppBundleIDs = ["com.apple.controlcenter", "com.apple.notificationcenterui"]

    /// Filters a list of windows to show only valid capture targets
    func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        windows.filter { window in
            isValidBasicWindow(window) && isNotSystemWindow(window)
        }
    }

    /// Validates basic window properties required for capture
    private func isValidBasicWindow(_ window: SCWindow) -> Bool {
        window.isOnScreen && window.frame.height > 100
            && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            && window.windowLayer == 0 && window.title != nil && !window.title!.isEmpty
    }

    /// Checks if window belongs to a system service that should be excluded
    private func isNotSystemWindow(_ window: SCWindow) -> Bool {
        let isNotDesktop =
            window.owningApplication?.bundleIdentifier != "com.apple.finder"
            || window.title != "Desktop"
        let isNotSystemUIServer =
            window.owningApplication?.bundleIdentifier != "com.apple.systemuiserver"
        let isNotSystemApp = !systemAppBundleIDs.contains(
            window.owningApplication?.bundleIdentifier ?? "")
        return isNotDesktop && isNotSystemUIServer && isNotSystemApp
    }
}

// MARK: - Window Focus Service
/// Manages window focus state and activation
///
/// Key responsibilities:
/// - Handles window activation requests
/// - Tracks focus state of captured windows
///
/// Coordinates with:
/// - CaptureManager: Provides window focus capabilities
/// - NSWorkspace: Monitors active application state
class WindowFocusService {
    /// Brings the captured window's application to the front
    ///
    /// - Parameters:
    ///   - window: The window to focus
    ///   - isEditModeEnabled: Whether edit mode is active (prevents focus in edit mode)
    func focusWindow(window: SCWindow, isEditModeEnabled: Bool) {
        guard !isEditModeEnabled,
            let processID = window.owningApplication?.processID
        else { return }

        NSRunningApplication(processIdentifier: pid_t(processID))?
            .activate()
    }

    /// Checks if the specified window's application is currently focused
    func updateFocusState(for window: SCWindow?) async -> Bool {
        guard let window = window,
            let activeApp = NSWorkspace.shared.frontmostApplication,
            let selectedApp = window.owningApplication
        else { return false }

        return activeApp.processIdentifier == selectedApp.processID
    }
}

// MARK: - Window Title Service
/// Manages window title updates and tracking
///
/// Key responsibilities:
/// - Updates window titles as they change
/// - Maintains current window title state
///
/// Coordinates with:
/// - CaptureManager: Provides current window titles
/// - SCShareableContent: Retrieves updated window information
class WindowTitleService {
    private let logger = Logger(
        subsystem: "com.Overview.WindowTitleService", category: "WindowTitle")

    /// Updates the title for a captured window
    ///
    /// Flow:
    /// 1. Retrieves current window list
    /// 2. Matches window by process ID and frame
    /// 3. Returns updated title if found
    func updateWindowTitle(for window: SCWindow?) async -> String? {
        guard let window = window else { return nil }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)
            return content.windows.first { updatedWindow in
                updatedWindow.owningApplication?.processID == window.owningApplication?.processID
                    && updatedWindow.frame == window.frame
            }?.title
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
/// - Manages notification observers lifecycle
///
/// Coordinates with:
/// - NSWorkspace: Monitors application activation
/// - NotificationCenter: Observes window state changes
/// - CaptureManager: Notifies of window state updates
class WindowObserverService {
    /// Callbacks for window state changes
    var onFocusStateChanged: (() async -> Void)?
    var onWindowTitleChanged: (() async -> Void)?

    private var workspaceObserver: NSObjectProtocol?
    private var windowObserver: NSObjectProtocol?
    private var titleCheckTimer: Timer?

    deinit {
        stopObserving()
    }

    /// Starts observing window state changes
    func startObserving() {
        setupWorkspaceObserver()
        setupWindowObserver()
        startTitleChecks()
    }

    /// Stops observing window state changes and cleans up observers
    func stopObserving() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        titleCheckTimer?.invalidate()
    }

    /// Sets up workspace activation monitoring
    private func setupWorkspaceObserver() {
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
    private func setupWindowObserver() {
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

    /// Initiates periodic window title checks
    private func startTitleChecks() {
        titleCheckTimer?.invalidate()
        titleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { [weak self] in
                await self?.onWindowTitleChanged?()
            }
        }
    }
}

// MARK: - Shareable Content Service
/// Manages screen capture permissions and window availability
///
/// Key responsibilities:
/// - Handles screen capture permission requests
/// - Retrieves available windows for capture
///
/// Coordinates with:
/// - SCShareableContent: Interfaces with system screen capture
/// - CaptureManager: Provides available windows for selection
class ShareableContentService {
    /// Requests screen capture permission from the system
    func requestPermission() async throws {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }

    /// Retrieves the current list of available windows for capture
    func getAvailableWindows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        return content.windows
    }
}
