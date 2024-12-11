/*
 HotkeyManager.swift
 Overview

 Created by William Pierce on 12/9/24.

 Coordinates window focusing operations through keyboard shortcuts, serving as the bridge
 between the HotkeyService and WindowService for hotkey-triggered window activation.

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
/// - Handles hotkey event registration with HotkeyService
/// - Executes window focus operations with WindowService
/// - Manages callback lifecycle for hotkey events
/// - Provides logging for debugging focus operations
///
/// Coordinates with:
/// - HotkeyService: Provides hotkey event notifications
/// - WindowService: Executes window focus operations
@MainActor
final class HotkeyManager: ObservableObject {
    // MARK: - Properties
    
    /// Logger for tracking window focus operations
    private let logger = Logger(
        subsystem: "com.Overview.HotkeyManager",
        category: "WindowFocus"
    )
    
    // MARK: - Initialization
    
    init() {
        // Register for hotkey events
        HotkeyService.shared.registerCallback(owner: self) { [weak self] windowTitle in
            Task { @MainActor in
                self?.focusWindowByTitle(windowTitle)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func focusWindowByTitle(_ windowTitle: String) {
        logger.debug("Focusing window with title: '\(windowTitle)'")
        
        if WindowManager.shared.focusWindow(withTitle: windowTitle) {
            logger.info("Successfully focused window: '\(windowTitle)'")
        } else {
            logger.warning("Failed to focus window: '\(windowTitle)'")
        }
    }
    
    deinit {
        HotkeyService.shared.removeCallback(for: self)
    }
}
