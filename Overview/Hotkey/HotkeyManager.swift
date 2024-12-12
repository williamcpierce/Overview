/*
 HotkeyManager.swift
 Overview

 Created by William Pierce on 12/9/24.

 Coordinates window focusing operations through keyboard shortcuts, serving as the bridge
 between the HotkeyService and WindowManager for hotkey-triggered window activation.
 Provides reliable window focus operations in response to global keyboard events.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import OSLog
import SwiftUI

/// Manages hotkey-triggered window focus operations across preview windows
///
/// Key responsibilities:
/// - Coordinates hotkey event handling with HotkeyService
/// - Executes window focus operations through WindowManager
/// - Manages callback registration lifecycle
/// - Provides reliable logging for focus operations
///
/// Coordinates with:
/// - HotkeyService: Provides hotkey event notifications
/// - WindowManager: Executes window focus operations
/// - OverviewApp: Initializes hotkey management system
@MainActor
final class HotkeyManager: ObservableObject {
    // MARK: - Initialization
    
    /// Creates hotkey manager and registers for hotkey events
    ///
    /// Flow:
    /// 1. Initializes logging system
    /// 2. Registers callback with HotkeyService
    /// 3. Configures window focus handling
    init() {
        AppLogger.hotkeys.debug("Initializing HotkeyManager")
        
        // Register for hotkey events with weak self reference
        // to prevent retain cycles during callback handling
        HotkeyService.shared.registerCallback(owner: self) { [weak self] windowTitle in
            Task { @MainActor in
                self?.focusWindowByTitle(windowTitle)
            }
        }
        
        AppLogger.hotkeys.info("HotkeyManager successfully initialized")
    }
    
    // MARK: - Private Methods
    
    /// Attempts to focus window with specified title
    ///
    /// Flow:
    /// 1. Logs focus attempt details
    /// 2. Requests focus through WindowManager
    /// 3. Logs operation outcome
    ///
    /// - Parameter windowTitle: Title of window to focus
    /// - Note: Operation logged as warning if focus fails
    private func focusWindowByTitle(_ windowTitle: String) {
        AppLogger.hotkeys.debug("Focusing window: '\(windowTitle)'")
        
        let success = WindowManager.shared.focusWindow(withTitle: windowTitle)
        
        if success {
            AppLogger.hotkeys.info("Successfully focused window: '\(windowTitle)'")
        } else {
            AppLogger.hotkeys.warning("Failed to focus window: '\(windowTitle)'")
        }
    }
    
    /// Removes hotkey callback registration on deallocation
    ///
    /// Flow:
    /// 1. Logs cleanup initiation
    /// 2. Removes callback from HotkeyService
    /// 3. Confirms cleanup completion
    deinit {
        AppLogger.hotkeys.debug("Cleaning up HotkeyManager")
        HotkeyService.shared.removeCallback(for: self)
        AppLogger.hotkeys.info("HotkeyManager cleanup completed")
    }
}
