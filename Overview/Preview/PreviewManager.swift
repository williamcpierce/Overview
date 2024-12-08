/*
 PreviewManager.swift
 Overview

 Created by William Pierce on 10/13/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Manages multiple window preview instances and coordinates global edit mode state
///
/// Key responsibilities:
/// - Creates and manages CaptureManager instances for each preview window
/// - Maintains global edit mode state shared across all preview windows
/// - Coordinates window preview lifecycle
///
/// Coordinates with:
/// - CaptureManager: Creates and maintains preview capture instances
/// - AppSettings: Provides configuration for new capture instances
/// - ContentView: Presents UI and handles edit mode state
@MainActor
final class PreviewManager: ObservableObject {
    // MARK: - Properties

    /// Active capture managers mapped by their unique identifiers
    @Published private(set) var captureManagers: [UUID: CaptureManager] = [:]

    /// Global edit mode state affecting all preview windows
    @Published var isEditModeEnabled = false

    /// Application settings used to configure new capture managers
    private let appSettings: AppSettings

    // MARK: - Initialization

    /// Creates a preview manager with the specified application settings
    init(appSettings: AppSettings) {
        self.appSettings = appSettings
    }

    // MARK: - Public Methods

    /// Creates a new capture manager instance with current app settings
    ///
    /// - Returns: Unique identifier for the created capture manager
    func createNewCaptureManager() -> UUID {
        let id = UUID()
        let captureManager = CaptureManager(appSettings: appSettings)
        captureManagers[id] = captureManager
        return id
    }

    /// Removes a capture manager and cleans up its resources
    ///
    /// - Parameter id: Unique identifier of the capture manager to remove
    func removeCaptureManager(id: UUID) {
        guard captureManagers[id] != nil else {
            print("Warning: Attempted to remove non-existent capture manager with ID \(id).")
            return
        }
        captureManagers.removeValue(forKey: id)
    }

    /// Toggles the global edit mode state affecting all preview windows
    func toggleEditMode() {
        isEditModeEnabled.toggle()
    }
}
