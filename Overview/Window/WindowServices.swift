/*
 WindowServices.swift
 Overview

 Created by William Pierce on 12/15/24.

 Provides centralized window-related services that can be shared across the application,
 reducing redundancy and improving performance by maintaining single instances of core
 window management functionality.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import ScreenCaptureKit

// MARK: - Window Filter Service

/// Filters and validates windows for capture compatibility
/// - Note: Shared instance via WindowServices.shared
final class WindowFilterService {
    // MARK: - Properties

    /// Logger for window filtering operations
    private let logger = AppLogger.windows

    /// System applications excluded from capture selection
    private let systemAppBundleIDs = [
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
    ]

    // MARK: - Public Methods

    /// Filters window list to show only valid capture targets
    func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        logger.debug("Filtering \(windows.count) windows")

        let filtered = windows.filter { window in
            isValidBasicWindow(window) && isNotSystemWindow(window)
        }

        logger.info("Found \(filtered.count) valid capture targets")
        return filtered
    }

    // MARK: - Private Methods

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

/// Manages window focus state and activation
/// - Note: Shared instance via WindowServices.shared
final class WindowFocusService {
    // MARK: - Properties

    private let logger = AppLogger.windows

    // MARK: - Public Methods

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

        let success =
            NSRunningApplication(processIdentifier: pid_t(processID))?
            .activate() ?? false

        if !success {
            logger.error("Failed to activate window: processID=\(processID)")
        }
    }

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
/// - Note: Shared instance via WindowServices.shared
final class WindowTitleService {
    // MARK: - Properties

    private let logger = AppLogger.windows

    // MARK: - Public Methods

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
/// - Note: Shared instance via WindowServices.shared
final class WindowObserverService {
    // MARK: - Properties

    private let logger = AppLogger.windows

    var onFocusStateChanged: (() async -> Void)?
    var onWindowTitleChanged: (() async -> Void)?

    private var workspaceObserver: NSObjectProtocol?
    private var windowObserver: NSObjectProtocol?
    private var titleCheckTimer: Timer?

    // MARK: - Lifecycle

    deinit {
        stopObserving()
    }

    // MARK: - Public Methods

    func startObserving() {
        logger.info("Starting window state observation")
        setupWorkspaceObserver()
        setupWindowObserver()
        startTitleChecks()
    }

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

    private func setupWorkspaceObserver() {
        logger.debug("Setting up workspace observer")

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

    private func setupWindowObserver() {
        logger.debug("Setting up window focus observer")

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

    private func startTitleChecks() {
        titleCheckTimer?.invalidate()

        logger.debug("Starting periodic title checks")

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
/// - Note: Shared instance via WindowServices.shared
final class ShareableContentService {
    // MARK: - Properties

    private let logger = AppLogger.capture

    // MARK: - Public Methods

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

// MARK: - Window Services Container

/// Provides centralized access to shared window-related services
/// - Note: Services are created once and shared across the application
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
