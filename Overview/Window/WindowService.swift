/*
 WindowService.swift
 Overview

 Created by William Pierce on 12/9/24

 Provides centralized window management capabilities independently of capture
 functionality, managing window discovery, focus operations, and state tracking
 across the application.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import OSLog
import ScreenCaptureKit

/// Manages window operations and state tracking across the application
///
/// Key responsibilities:
/// - Provides real-time window state tracking and caching
/// - Handles window focus operations and validation
/// - Coordinates window discovery and filtering
/// - Maintains periodic window state updates
///
/// Coordinates with:
/// - ShareableContentService: Retrieves available windows
/// - WindowFilterService: Validates capture compatibility
/// - HotkeyManager: Processes focus requests
/// - CaptureManager: Provides window state updates
@MainActor
class WindowService {
    // MARK: - Properties

    /// Shared instance for app-wide window management
    /// - Note: Enforces singleton pattern for consistent state
    static let shared = WindowService()

    /// Maps window titles to window references for quick lookup
    /// - Note: Updated periodically to maintain accuracy
    private var windowCache: [String: SCWindow] = [:]

    /// Service dependencies for window operations
    private let shareableContent = ShareableContentService()
    private let windowFilter = WindowFilterService()

    /// Timer for periodic window cache updates
    /// - Note: Maintains cache freshness without blocking
    private var updateTimer: Timer?

    // MARK: - Initialization

    /// Creates window service and initializes tracking
    /// - Important: Private to enforce singleton pattern
    private init() {
        setupWindowTracking()
    }

    // MARK: - Public Methods

    /// Activates window with specified title
    ///
    /// Flow:
    /// 1. Validates window exists in current cache
    /// 2. Retrieves application process identifier
    /// 3. Activates window's parent application
    /// 4. Reports success or failure
    ///
    /// - Parameter title: Title of window to focus
    /// - Returns: Whether focus operation succeeded
    @discardableResult
    func focusWindow(withTitle title: String) -> Bool {
        AppLogger.windows.debug("Attempting to focus window: '\(title)'")
        
        guard let window = windowCache[title],
            let processID = window.owningApplication?.processID
        else {
            AppLogger.windows.warning("No window found with title: '\(title)'")
            return false
        }

        AppLogger.windows.info("Focusing window: '\(title)' (PID: \(processID))")
        let success = NSRunningApplication(processIdentifier: pid_t(processID))?
            .activate() ?? false
            
        if !success {
            AppLogger.windows.error("Failed to activate window: '\(title)'")
        }
        return success
    }

    /// Retrieves filtered list of available windows
    ///
    /// Flow:
    /// 1. Updates window cache state
    /// 2. Returns current window collection
    /// 3. Maintains consistent window order
    ///
    /// - Returns: Array of available windows for capture
    /// - Note: Windows are filtered based on capture compatibility
    func getAvailableWindows() async -> [SCWindow] {
        AppLogger.windows.debug("Retrieving available windows")
        await updateWindowState()
        return Array(windowCache.values)
    }

    // MARK: - Private Methods

    /// Updates window cache with current system state
    ///
    /// Flow:
    /// 1. Retrieves current shareable content
    /// 2. Applies window filtering rules
    /// 3. Updates cache with valid windows
    /// 4. Logs cache update metrics
    ///
    /// - Warning: Must be called from MainActor context
    private func updateWindowState() async {
        AppLogger.windows.debug("Updating window cache state")
        
        do {
            let windows = try await shareableContent.getAvailableWindows()
            let filtered = windowFilter.filterWindows(windows)

            windowCache.removeAll()
            for window in filtered {
                if let title = window.title {
                    windowCache[title] = window
                }
            }

            AppLogger.windows.info("Window cache updated: \(windowCache.count) windows")
        } catch {
            AppLogger.logError(error,
                             context: "Failed to update window state",
                             logger: AppLogger.windows)
        }
    }

    /// Configures periodic window state updates
    ///
    /// Flow:
    /// 1. Creates update timer with 2-second interval
    /// 2. Configures update callback
    /// 3. Begins tracking cycle
    ///
    /// - Important: Balance update frequency with performance
    /// - Note: Updates run on main actor to maintain consistency
    private func setupWindowTracking() {
        AppLogger.windows.debug("Initializing window tracking")
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateWindowState()
            }
        }
    }

    /// Cleanup timer on deallocation
    /// - Warning: Required to prevent timer retention
    deinit {
        AppLogger.windows.debug("Cleaning up window service")
        updateTimer?.invalidate()
    }
}
