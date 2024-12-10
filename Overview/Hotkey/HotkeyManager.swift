/*
 HotkeyManager.swift
 Overview

 Created by William Pierce on 12/9/24.

 Coordinates window focusing operations through keyboard shortcuts, serving as the bridge
 between the HotkeyService and PreviewManager for hotkey-triggered window activation.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI
import OSLog

/// Manages hotkey-triggered window focus operations across preview windows
///
/// Key responsibilities:
/// - Handles hotkey event registration with HotkeyService
/// - Coordinates window focus state with PreviewManager
/// - Manages callback lifecycle for hotkey events
/// - Provides logging for debugging focus operations
///
/// Coordinates with:
/// - HotkeyService: Provides hotkey event notifications
/// - PreviewManager: Handles window focus state changes
/// - CaptureManager: Executes window focus operations
@MainActor
final class HotkeyManager: ObservableObject {
    // MARK: - Properties

    /// Reference to preview manager for window focus operations
    /// - Note: Weak reference prevents retention cycle
    private weak var previewManager: PreviewManager?
    
    /// Logger for tracking window focus operations
    /// - Note: Categorized for focused debugging
    private let logger = Logger(
        subsystem: "com.Overview.HotkeyManager",
        category: "WindowFocus"
    )
    
    /// Cache of window title to capture manager mappings
    /// - Note: Updated when preview manager state changes
    private var windowTitleCache: [String: CaptureManager] = [:]

    // MARK: - Initialization
    
    /// Creates hotkey manager and registers for hotkey events
    ///
    /// Flow:
    /// 1. Stores preview manager reference
    /// 2. Registers callback with HotkeyService
    /// 3. Configures async event handling
    /// 4. Sets up window title cache
    ///
    /// - Parameter previewManager: Manager for preview window operations
    /// - Note: Callback registration is removed in deinit
    init(previewManager: PreviewManager) {
        self.previewManager = previewManager
        
        // Context: Using weak self prevents retain cycle with callback
        HotkeyService.shared.registerCallback(owner: self) { [weak self] windowTitle in
            Task { @MainActor in
                self?.focusWindowByTitle(windowTitle)
            }
        }
        
        // Initial cache population
        updateWindowTitleCache()
    }

    // MARK: - Private Methods

    /// Focuses window matching provided title through preview manager
    ///
    /// Flow:
    /// 1. Validates preview manager reference
    /// 2. Updates title cache for current state
    /// 3. Looks up capture manager by title
    /// 4. Triggers window focus operation
    ///
    /// - Parameter windowTitle: Title of window to focus
    /// - Note: Cache provides O(1) lookup for window focus operations
    private func focusWindowByTitle(_ windowTitle: String) {
        logger.debug("Focusing window with title: '\(windowTitle)'")
        
        guard let previewManager = previewManager else {
            logger.error("Preview manager reference lost")
            return
        }
        
        // Ensure cache is current before lookup
        updateWindowTitleCache()
        
        if let captureManager = windowTitleCache[windowTitle] {
            logger.debug("Found matching window, triggering focus")
            captureManager.focusWindow(isEditModeEnabled: false)
        } else {
            logger.warning("No window found with title: '\(windowTitle)'")
        }
    }
    
    /// Updates cache of window titles to capture managers
    ///
    /// Flow:
    /// 1. Clears existing cache
    /// 2. Iterates current capture managers
    /// 3. Maps window titles to managers
    ///
    /// - Note: O(n) operation but prevents repeated iteration during focus
    private func updateWindowTitleCache() {
        windowTitleCache.removeAll()
        
        guard let previewManager = previewManager else { return }
        
        for (_, manager) in previewManager.captureManagers {
            if let title = manager.windowTitle {
                windowTitleCache[title] = manager
            }
        }
    }

    // MARK: - Cleanup

    /// Removes hotkey callback registration on deallocation
    /// - Warning: Required to prevent callback retention
    deinit {
        HotkeyService.shared.removeCallback(for: self)
    }
}
