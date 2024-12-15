/*
 WindowManager.swift
 Overview

 Created by William Pierce on 12/10/24

 Provides centralized window management operations across the application, serving as
 the single source of truth for window state tracking and focus operations. Manages
 window caching and periodic updates to ensure efficient window lookup with minimal
 system overhead.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import ScreenCaptureKit

/// Manages window operations and state tracking across the application using a centralized cache
///
/// Key responsibilities:
/// - Maintains efficient window title-to-window mapping for quick lookups
/// - Provides filtered window lists excluding system windows
/// - Executes window focus operations through system APIs
/// - Updates window state periodically to maintain accuracy
///
/// Coordinates with:
/// - WindowFilterService: Filters out invalid capture targets
/// - ShareableContentService: Retrieves system window information
/// - HotkeyManager: Processes keyboard shortcut focus requests
/// - PreviewView: Provides window state for display updates
/// - WindowServices: Accesses shared window operations
@MainActor
final class WindowManager {
    // MARK: - Properties

    /// Shared instance for app-wide window management
    /// - Note: Created once and reused across components
    static let shared = WindowManager()

    /// Provides access to shared window operation services
    /// - Note: Single point of access for all window-related services
    private let services = WindowServices.shared

    /// Maps window titles to window objects for O(1) lookup time
    /// - Note: Updated every 2 seconds to balance accuracy and performance
    private var windowCache: [String: SCWindow] = [:]

    /// Timer that triggers periodic window cache updates
    /// - Warning: Must be invalidated in deinit to prevent memory leaks
    private var updateTimer: Timer?

    // MARK: - Initialization

    /// Creates window manager and initializes window tracking system
    ///
    /// Flow:
    /// 1. Creates singleton instance
    /// 2. Initializes empty window cache
    /// 3. Starts periodic update timer
    ///
    /// - Important: Must be accessed through shared property
    private init() {
        AppLogger.windows.debug("Initializing WindowManager singleton")
        setupWindowTracking()
    }

    // MARK: - Public Methods

    /// Retrieves filtered list of available windows for capture
    ///
    /// Flow:
    /// 1. Requests raw window list from system
    /// 2. Applies window filters to remove invalid targets
    /// 3. Updates window cache with current state
    /// 4. Returns filtered window collection
    ///
    /// - Returns: Array of available windows that can be captured
    /// - Note: Updates window cache as side effect for efficient lookup
    func getAvailableWindows() async -> [SCWindow] {
        AppLogger.windows.debug("Retrieving current window list from system")

        do {
            let windows = try await services.shareableContent.getAvailableWindows()
            let filtered = services.windowFilter.filterWindows(windows)

            // Update cache while we have fresh window data
            updateWindowCache(filtered)

            AppLogger.windows.info("Retrieved \(filtered.count) available windows")
            return filtered
        } catch {
            AppLogger.logError(
                error,
                context: "Failed to get available windows from system",
                logger: AppLogger.windows
            )
            return []
        }
    }

    /// Attempts to focus a window identified by its title
    ///
    /// Flow:
    /// 1. Looks up window in cache using O(1) title lookup
    /// 2. Retrieves owning application process ID
    /// 3. Requests system window activation
    /// 4. Returns operation success state
    ///
    /// - Parameter title: Title of window to bring to front
    /// - Returns: True if window was successfully focused
    /// - Important: Uses cached window state to minimize system calls
    @discardableResult
    func focusWindow(withTitle title: String) -> Bool {
        AppLogger.windows.debug("Requesting focus for window: '\(title)'")

        // Context: Process ID required for activation through AppKit
        guard let window = windowCache[title],
            let processID = window.owningApplication?.processID
        else {
            AppLogger.windows.warning("No window found in cache with title: '\(title)'")
            return false
        }

        let success = NSRunningApplication(processIdentifier: pid_t(processID))?.activate() ?? false

        if success {
            AppLogger.windows.info("Window focus successful: '\(title)'")
        } else {
            AppLogger.windows.error(
                "Failed to activate window process: '\(title)', pid: \(processID)")
        }

        return success
    }

    // MARK: - Private Methods

    /// Configures timer for periodic window cache updates
    ///
    /// Flow:
    /// 1. Creates repeating timer with 2-second interval
    /// 2. Schedules async window list updates
    /// 3. Maintains window cache freshness
    ///
    /// - Note: 2-second interval balances accuracy and performance
    private func setupWindowTracking() {
        AppLogger.windows.debug("Configuring window tracking timer")

        // Context: Using 2-second interval to balance state freshness and system load
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                _ = await self?.getAvailableWindows()
            }
        }

        AppLogger.windows.info("Window tracking initialized with 2-second refresh")
    }

    /// Updates window cache with current window state
    ///
    /// Flow:
    /// 1. Clears existing cache entries
    /// 2. Maps valid windows by title for O(1) lookup
    /// 3. Ignores windows without valid titles
    ///
    /// - Parameter windows: Current list of valid windows
    /// - Important: Only windows with non-empty titles are cached
    private func updateWindowCache(_ windows: [SCWindow]) {
        AppLogger.windows.debug("Updating window title cache")

        windowCache.removeAll()
        for window in windows {
            if let title = window.title {
                windowCache[title] = window
            }
        }

        AppLogger.windows.info("Window cache updated with \(windowCache.count) entries")
    }

    /// Cleanup resources when instance is deallocated
    /// - Warning: Required to prevent timer resource leaks
    deinit {
        AppLogger.windows.debug("WindowManager deallocating, stopping update timer")
        updateTimer?.invalidate()
    }
}
