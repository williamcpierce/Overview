/*
 WindowManager.swift
 Overview

 Created by William Pierce on 12/10/24
 
 Provides centralized window management capabilities, handling window operations
 across the application in a simpler, more maintainable way.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import OSLog
import ScreenCaptureKit

@MainActor
final class WindowManager {
    // MARK: - Properties
    
    /// Shared instance for app-wide window management
    static let shared = WindowManager()
    
    /// System logger for window operations
    private let logger = Logger(
        subsystem: "com.Overview.WindowManager",
        category: "WindowManagement"
    )
    
    /// Services for window operations
    private let windowFilter = WindowFilterService()
    private let shareableContent = ShareableContentService()
    
    /// Map of window titles to windows for quick lookup
    private var windowCache: [String: SCWindow] = [:]
    
    /// Timer for periodic window cache updates
    private var updateTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        setupWindowTracking()
    }
    
    // MARK: - Public Methods
    
    /// Gets all available windows for capture
    /// - Returns: Array of available windows
    func getAvailableWindows() async -> [SCWindow] {
        do {
            let windows = try await shareableContent.getAvailableWindows()
            let filtered = windowFilter.filterWindows(windows)
            
            // Update cache while we have fresh data
            updateWindowCache(filtered)
            
            return filtered
        } catch {
            logger.error("Failed to get windows: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Focuses a window by its title
    /// - Parameter title: Title of the window to focus
    /// - Returns: Whether the focus operation succeeded
    @discardableResult
    func focusWindow(withTitle title: String) -> Bool {
        guard let window = windowCache[title],
              let processID = window.owningApplication?.processID else {
            logger.warning("No window found with title: '\(title)'")
            return false
        }
        
        logger.info("Focusing window: '\(title)'")
        return NSRunningApplication(processIdentifier: pid_t(processID))?
            .activate() ?? false
    }
    
    // MARK: - Private Methods
    
    /// Sets up periodic window cache updates
    private func setupWindowTracking() {
        // Update every 2 seconds to balance freshness and performance
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                _ = await self?.getAvailableWindows()
            }
        }
    }
    
    /// Updates the window title cache
    /// - Parameter windows: Current list of valid windows
    private func updateWindowCache(_ windows: [SCWindow]) {
        windowCache.removeAll()
        for window in windows {
            if let title = window.title {
                windowCache[title] = window
            }
        }
        logger.debug("Window cache updated, count: \(self.windowCache.count)")
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}
