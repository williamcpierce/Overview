/*
 WindowManager.swift
 Overview

 Created by William Pierce on 12/10/24

 Provides centralized window management operations across the application, handling
 window discovery, focus operations, and state tracking. Acts as the primary interface
 for window-related operations in Overview.

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
/// - Maintains current window state with efficient caching
/// - Handles window discovery and filtering operations
/// - Manages window focus and activation requests
/// - Provides periodic window state updates
///
/// Coordinates with:
/// - WindowFilterService: Validates and filters window listings
/// - ShareableContentService: Retrieves system window information
/// - HotkeyManager: Processes window focus requests
/// - PreviewView: Provides window state for UI updates
@MainActor
final class WindowManager {
    // MARK: - Properties

    /// Shared instance for app-wide window management
    static let shared = WindowManager()

    /// Service dependencies for window operations
    private let windowFilter = WindowFilterService()
    private let shareableContent = ShareableContentService()

    /// Maps window titles to windows for efficient lookup
    /// - Note: Updated periodically to maintain accuracy
    private var windowCache: [String: SCWindow] = [:]

    /// Timer for periodic window cache updates
    /// - Note: Maintains 2-second refresh interval
    private var updateTimer: Timer?

    // MARK: - Initialization

    /// Creates window manager and initializes tracking
    ///
    /// Flow:
    /// 1. Creates shared instance
    /// 2. Configures window tracking timer
    /// 3. Initializes empty window cache
    private init() {
        AppLogger.windows.debug("Initializing WindowManager")
        setupWindowTracking()
    }

    // MARK: - Public Methods

    /// Retrieves filtered list of available windows
    ///
    /// Flow:
    /// 1. Requests current shareable content
    /// 2. Applies window filters
    /// 3. Updates window cache
    /// 4. Returns filtered window list
    ///
    /// - Returns: Array of available windows meeting filter criteria
    /// - Note: Updates window cache as side effect
    func getAvailableWindows() async -> [SCWindow] {
        AppLogger.windows.debug("Retrieving available windows")
        do {
            let windows = try await shareableContent.getAvailableWindows()
            let filtered = windowFilter.filterWindows(windows)
            
            // Update cache while we have fresh data
            updateWindowCache(filtered)
            
            AppLogger.windows.info("Retrieved \(filtered.count) available windows")
            return filtered
        } catch {
            AppLogger.logError(error,
                             context: "Failed to get available windows",
                             logger: AppLogger.windows)
            return []
        }
    }

    /// Activates window with specified title
    ///
    /// Flow:
    /// 1. Looks up window in cache by title
    /// 2. Retrieves process information
    /// 3. Attempts window activation
    /// 4. Returns operation success
    ///
    /// - Parameter title: Title of window to focus
    /// - Returns: Whether focus operation succeeded
    /// - Important: Uses cached window state for efficient lookup
    @discardableResult
    func focusWindow(withTitle title: String) -> Bool {
        AppLogger.windows.debug("Attempting to focus window: '\(title)'")
        
        guard let window = windowCache[title],
              let processID = window.owningApplication?.processID else {
            AppLogger.windows.warning("No window found with title: '\(title)'")
            return false
        }
        
        let success = NSRunningApplication(processIdentifier: pid_t(processID))?
            .activate() ?? false
            
        if success {
            AppLogger.windows.info("Successfully focused window: '\(title)'")
        } else {
            AppLogger.windows.error("Failed to focus window: '\(title)'")
        }
        
        return success
    }

    // MARK: - Private Methods

    /// Configures periodic window cache updates
    ///
    /// Flow:
    /// 1. Creates update timer
    /// 2. Sets 2-second refresh interval
    /// 3. Initiates window tracking
    ///
    /// - Important: Balance between freshness and performance
    private func setupWindowTracking() {
        AppLogger.windows.debug("Setting up window tracking")
        
        // Update every 2 seconds to balance freshness and performance
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                _ = await self?.getAvailableWindows()
            }
        }
        
        AppLogger.windows.info("Window tracking initialized with 2-second interval")
    }

    /// Updates window cache with current window state
    ///
    /// Flow:
    /// 1. Clears existing cache
    /// 2. Maps windows by title
    /// 3. Updates cache atomically
    ///
    /// - Parameter windows: Current list of valid windows
    /// - Important: Only caches windows with valid titles
    private func updateWindowCache(_ windows: [SCWindow]) {
        AppLogger.windows.debug("Updating window cache")
        
        windowCache.removeAll()
        for window in windows {
            if let title = window.title {
                windowCache[title] = window
            }
        }
        
        AppLogger.windows.info("Window cache updated with \(windowCache.count) windows")
    }

    /// Cleanup timer on deallocation
    /// - Warning: Required to prevent timer resource leaks
    deinit {
        AppLogger.windows.debug("WindowManager deinitializing")
        updateTimer?.invalidate()
    }
}
