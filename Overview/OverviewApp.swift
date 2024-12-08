/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Main application entry point that configures the app window and global settings
///
/// Key responsibilities:
/// - Initializes core application state (PreviewManager and AppSettings)
/// - Configures main window appearance and default size
///
/// Coordinates with:
/// - PreviewManager: Manages the creation and lifecycle of preview windows
/// - AppSettings: Handles persistent application configuration
@main
struct OverviewApp: App {
    // MARK: - Properties
    @StateObject private var previewManager: PreviewManager
    @StateObject private var appSettings = AppSettings()

    // MARK: - Initialization
    /// Creates the app instance and initializes core services
    init() {
        let settings = AppSettings()
        self._appSettings = StateObject(wrappedValue: settings)
        self._previewManager = StateObject(wrappedValue: PreviewManager(appSettings: settings))
    }

    // MARK: - Body
    var body: some Scene {
        /// Main window configuration
        WindowGroup {
            ContentView(
                previewManager: previewManager,
                isEditModeEnabled: $previewManager.isEditModeEnabled,
                appSettings: appSettings
            )
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .defaultSize(
            width: appSettings.defaultWindowWidth,
            height: appSettings.defaultWindowHeight
        )
        .commands {
            /// Context: Edit mode can be toggled via menu
            CommandMenu("Edit") {
                Toggle("Edit Mode", isOn: $previewManager.isEditModeEnabled)
            }
        }

        /// Settings window configuration
        Settings {
            SettingsView(appSettings: appSettings)
        }
    }
}
