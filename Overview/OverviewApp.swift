/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 Main application entry point that manages the app lifecycle, window configuration,
 and global state initialization. Serves as the root coordinator for all major
 app components.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Root application scene that configures global state and window presentation
///
/// Key responsibilities:
/// - Initializes core application state (PreviewManager and AppSettings)
/// - Configures main window appearance and style
/// - Manages settings window presentation
/// - Provides global menu commands
///
/// Coordinates with:
/// - PreviewManager: Global edit mode and preview window lifecycle
/// - AppSettings: User preferences and window configuration
/// - ContentView: Main window content and preview display
/// - SettingsView: User preferences interface
@main
struct OverviewApp: App {
    // MARK: - Properties

    /// Controls preview window lifecycle and global edit mode
    @StateObject private var previewManager: PreviewManager

    /// Manages persistent user preferences and window configuration
    @StateObject private var appSettings = AppSettings()

    // MARK: - Initialization

    /// Creates the app instance and initializes core services
    ///
    /// Flow:
    /// 1. Creates AppSettings for user preferences
    /// 2. Initializes PreviewManager with settings reference
    /// 3. Wraps managers in StateObjects for SwiftUI state management
    init() {
        // Create settings first as PreviewManager depends on them
        let settings = AppSettings()
        self._appSettings = StateObject(wrappedValue: settings)
        self._previewManager = StateObject(wrappedValue: PreviewManager(appSettings: settings))
    }

    // MARK: - Scene Configuration

    var body: some Scene {
        // MARK: Main Window Scene
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
            CommandMenu("Edit") {
                Toggle("Edit Mode", isOn: $previewManager.isEditModeEnabled)
            }
        }

        // MARK: Settings Scene
        Settings {
            SettingsView(
                appSettings: appSettings,
                previewManager: previewManager  // Pass PreviewManager instead
            )
        }
    }
}
