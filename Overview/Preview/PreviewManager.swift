/*
 PreviewManager.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages multiple window preview instances and coordinates their lifecycle,
 providing centralized control of capture sessions and edit mode state.
 Core orchestrator for Overview's window preview system.
*/

import SwiftUI

/// Thread-confined type that orchestrates window preview lifecycle and state management.
/// Must be accessed only from the main actor to ensure state consistency.
///
/// Coordinates window preview configuration across all instances:
/// - Window capture and preview rendering configuration
/// - Global edit mode state synchronization
/// - Preview window lifecycle and cleanup
@MainActor
final class PreviewManager: ObservableObject {
    @Published private(set) var captureManagers: [UUID: CaptureManager] = [:]
    @Published var isEditModeEnabled = false
    private let userSettings: AppSettings

    init(appSettings: AppSettings) {
        self.userSettings = appSettings
        AppLogger.windows.debug("PreviewManager initialized")
    }

    /// Creates and registers a new capture manager instance.
    /// Returns a unique identifier for future capture manager access.
    func createNewCaptureManager() -> UUID {
        let managerId = UUID()
        let manager = CaptureManager(appSettings: userSettings)
        captureManagers[managerId] = manager

        AppLogger.windows.info(
            "Created capture manager: \(managerId), total active: \(captureManagers.count)")
        return managerId
    }

    /// Safely removes a capture manager instance and its associated resources.
    /// Safe to call with invalid IDs - logs warning but takes no action.
    func removeCaptureManager(id: UUID) {
        guard captureManagers[id] != nil else {
            AppLogger.windows.warning("Attempted to remove non-existent capture manager: \(id)")
            return
        }

        captureManagers.removeValue(forKey: id)
        AppLogger.windows.info(
            "Removed capture manager: \(id), remaining active: \(captureManagers.count)")
    }

    /// Toggles window edit mode across all preview instances.
    /// When enabled, windows can be moved and resized. Window level adjusts to facilitate positioning.
    func toggleEditMode() {
        isEditModeEnabled.toggle()
        AppLogger.interface.info("Edit mode \(isEditModeEnabled ? "enabled" : "disabled")")
        AppLogger.interface.debug("Active preview windows during toggle: \(captureManagers.count)")
    }
}
