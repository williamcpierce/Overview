/*
 WindowService.swift
 Overview

 Created by William Pierce on 12/9/24

 Provides centralized window management capabilities, handling window discovery,
 focus operations, and state tracking independently of capture functionality.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import OSLog
import ScreenCaptureKit

/// Manages window operations independently of capture functionality
///
/// Key responsibilities:
/// - Maintains current window state across the system
/// - Handles window focus operations
/// - Provides window discovery and filtering
/// - Coordinates with system window management
///
/// Coordinates with:
/// - ShareableContentService: Window discovery
/// - WindowFilterService: Window validation
/// - HotkeyManager: Window focus operations
/// - CaptureManager: Window state updates
@MainActor
class WindowService {
    // MARK: - Properties

    /// Shared instance for app-wide window management
    static let shared = WindowService()

    /// System logger for window operations
    private let logger = Logger(
        subsystem: "com.Overview.WindowService",
        category: "WindowManagement"
    )

    /// Current system window state
    /// - Note: Updated periodically to maintain accuracy
    private var windowCache: [String: SCWindow] = [:]

    /// Service dependencies
    private let shareableContent = ShareableContentService()
    private let windowFilter = WindowFilterService()

    /// Update timer for window state
    private var updateTimer: Timer?

    // MARK: - Initialization

    private init() {
        setupWindowTracking()
    }

    // MARK: - Public Methods

    /// Focuses window with specified title
    ///
    /// Flow:
    /// 1. Validates window exists in current state
    /// 2. Retrieves window information
    /// 3. Activates window's application
    ///
    /// - Parameter title: Title of window to focus
    /// - Returns: Whether focus operation succeeded
    @discardableResult
    func focusWindow(withTitle title: String) -> Bool {
        guard let window = windowCache[title],
            let processID = window.owningApplication?.processID
        else {
            logger.warning("No window found with title: '\(title)'")
            return false
        }

        logger.info("Focusing window: '\(title)'")
        return NSRunningApplication(processIdentifier: pid_t(processID))?
            .activate() ?? false
    }

    /// Returns filtered list of available windows
    ///
    /// Flow:
    /// 1. Updates current window state
    /// 2. Applies window filters
    /// 3. Returns valid windows
    ///
    /// - Returns: Array of available windows
    func getAvailableWindows() async -> [SCWindow] {
        await updateWindowState()
        return Array(windowCache.values)
    }

    /// Updates window cache with current system state
    ///
    /// Flow:
    /// 1. Retrieves current shareable content
    /// 2. Filters valid windows
    /// 3. Updates cache state
    private func updateWindowState() async {
        do {
            let windows = try await shareableContent.getAvailableWindows()
            let filtered = windowFilter.filterWindows(windows)

            // Update cache with valid windows
            windowCache.removeAll()
            for window in filtered {
                if let title = window.title {
                    windowCache[title] = window
                }
            }

            logger.debug("Window cache updated, count: \(self.windowCache.count)")
        } catch {
            logger.error("Failed to update window state: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    /// Sets up periodic window state updates
    ///
    /// Flow:
    /// 1. Creates update timer
    /// 2. Configures update interval
    /// 3. Starts tracking
    private func setupWindowTracking() {
        // Update every 2 seconds to balance freshness and performance
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateWindowState()
            }
        }
    }

    deinit {
        updateTimer?.invalidate()
    }
}
