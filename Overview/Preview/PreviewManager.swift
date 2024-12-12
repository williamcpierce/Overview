/*
 PreviewManager.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages multiple window preview instances and coordinates their lifecycle,
 providing centralized control of capture sessions and edit mode state.
 Core orchestrator for Overview's window preview system.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Manages multiple window preview instances and coordinates global preview state
///
/// Key responsibilities:
/// - Creates and manages CaptureManager instances for preview windows
/// - Maintains global edit mode state across preview instances
/// - Coordinates preview window lifecycle and resource cleanup
/// - Handles capture manager instance creation and disposal
///
/// Coordinates with:
/// - CaptureManager: Individual window capture and preview instances
/// - AppSettings: Configuration for new capture managers
/// - ContentView: Main window content and edit mode coordination
/// - WindowAccessor: Window behavior during edit mode changes
@MainActor
final class PreviewManager: ObservableObject {
    // MARK: - Properties

    /// Active capture managers for each preview window
    /// - Note: Mapped by UUID for efficient lookup and removal
    @Published private(set) var captureManagers: [UUID: CaptureManager] = [:]

    /// Global edit mode state affecting all preview windows
    /// - Note: Changes propagate immediately to all preview instances
    @Published var isEditModeEnabled = false

    /// User preferences for configuring new capture managers
    private let appSettings: AppSettings

    // MARK: - Initialization

    /// Creates a preview manager with user preferences
    ///
    /// Flow:
    /// 1. Stores settings reference for new capture managers
    /// 2. Initializes empty capture manager collection
    /// 3. Sets default edit mode state
    ///
    /// - Parameter appSettings: User preferences for capture configuration
    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        AppLogger.windows.debug("PreviewManager initialized")
    }

    // MARK: - Public Methods

    /// Creates a new capture manager with current settings
    ///
    /// Flow:
    /// 1. Generates unique identifier
    /// 2. Creates capture manager with user preferences
    /// 3. Stores manager in active collection
    ///
    /// - Returns: UUID for accessing the new capture manager
    func createNewCaptureManager() -> UUID {
        let id = UUID()
        
        AppLogger.windows.debug("Creating new capture manager with ID: \(id)")
        
        let captureManager = CaptureManager(appSettings: appSettings)
        captureManagers[id] = captureManager
        
        AppLogger.windows.info("Created capture manager: \(id), total active: \(captureManagers.count)")
        return id
    }

    /// Removes a capture manager and cleans up resources
    ///
    /// Flow:
    /// 1. Validates manager exists
    /// 2. Removes from active collection
    /// 3. Resources cleaned up via ARC
    ///
    /// - Parameter id: UUID of manager to remove
    /// - Note: Invalid IDs logged but not treated as errors
    func removeCaptureManager(id: UUID) {
        AppLogger.windows.debug("Attempting to remove capture manager: \(id)")
        
        guard captureManagers[id] != nil else {
            AppLogger.windows.warning("Attempted to remove non-existent capture manager: \(id)")
            return
        }
        
        captureManagers.removeValue(forKey: id)
        AppLogger.windows.info("Removed capture manager: \(id), remaining active: \(captureManagers.count)")
    }

    /// Toggles global edit mode affecting all preview windows
    ///
    /// Context: Edit mode enables window movement and resizing while
    /// temporarily adjusting window level for easier positioning
    func toggleEditMode() {
        isEditModeEnabled.toggle()
        AppLogger.interface.info("Edit mode \(isEditModeEnabled ? "enabled" : "disabled")")
        
        // Context: Log active window count to help track edit mode impact
        AppLogger.interface.debug("Active preview windows during toggle: \(captureManagers.count)")
    }
}
