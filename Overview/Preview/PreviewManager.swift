/*
 Preview/PreviewManager.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages multiple window preview instances and coordinates their lifecycle,
 providing centralized control of capture sessions and edit mode state.
 Core orchestrator for Overview's window preview system.
*/

import SwiftUI

@MainActor
final class PreviewManager: ObservableObject {
    @ObservedObject private var appSettings: AppSettings
    @Published private(set) var captureManagers: [UUID: CaptureManager] = [:]
    @Published var editMode = false

    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        AppLogger.windows.info("PreviewManager initialized")
    }

    func createNewCaptureManager() -> UUID {
        let managerId = UUID()
        let manager = CaptureManager(appSettings: appSettings)
        captureManagers[managerId] = manager

        AppLogger.windows.info(
            "Created capture manager: \(managerId), total active: \(captureManagers.count)")
        return managerId
    }

    func removeCaptureManager(id: UUID) {
        guard captureManagers[id] != nil else {
            AppLogger.windows.warning("Attempted to remove non-existent capture manager: \(id)")
            return
        }

        captureManagers.removeValue(forKey: id)
        AppLogger.windows.info(
            "Removed capture manager: \(id), remaining active: \(captureManagers.count)")
    }

    func toggleEditMode() {
        editMode.toggle()
        AppLogger.interface.info("Edit mode \(editMode ? "enabled" : "disabled")")
    }
}
