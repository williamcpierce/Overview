/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 Main application entry point that manages the app lifecycle, window configuration,
 and global state initialization. Serves as the root coordinator for all major
 app components, handling window presentation and global keyboard shortcuts.

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
/// - Coordinates hotkey system initialization
///
/// Coordinates with:
/// - PreviewManager: Global edit mode and preview window lifecycle
/// - AppSettings: User preferences and window configuration
/// - ContentView: Main window content and preview display
/// - SettingsView: User preferences interface
/// - HotkeyManager: Global keyboard shortcut handling
/// - WindowManager: Window focus and management operations
@main
struct OverviewApp: App {
    // MARK: - Properties

    /// Controls preview window lifecycle and global edit mode
    /// - Note: Created during initialization with settings reference
    @StateObject private var previewManager: PreviewManager
    
    /// Manages persistent user preferences and window configuration
    /// - Note: Must be initialized before PreviewManager
    @StateObject private var appSettings: AppSettings

    /// Coordinates keyboard shortcuts for window focus operations
    /// - Note: Requires WindowManager initialization before creation
    @StateObject private var hotkeyManager: HotkeyManager

    // MARK: - Initialization

    /// Creates the app instance and initializes core services
    ///
    /// Flow:
    /// 1. Creates AppSettings for user preferences
    /// 2. Initializes PreviewManager with settings reference
    /// 3. Ensures WindowManager singleton initialization
    /// 4. Creates HotkeyManager for keyboard shortcuts
    /// 5. Wraps managers in StateObjects for SwiftUI state management
    /// 6. Registers saved hotkey bindings from settings
    init() {
        AppLogger.interface.debug("Initializing application components")

        // Create settings first as PreviewManager depends on them
        let settings = AppSettings()
        let preview = PreviewManager(appSettings: settings)

        // Context: WindowManager must be initialized before HotkeyManager
        // to ensure proper window focus handling
        _ = WindowManager.shared
        
        self._appSettings = StateObject(wrappedValue: settings)
        self._previewManager = StateObject(wrappedValue: preview)
        self._hotkeyManager = StateObject(wrappedValue: HotkeyManager())
        
        AppLogger.hotkeys.debug("Registering saved hotkey bindings")
        // Register any saved hotkeys from previous launch
        HotkeyService.shared.registerHotkeys(settings.hotkeyBindings)

        AppLogger.interface.info("Application initialization complete")
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
            .onAppear {
                AppLogger.hotkeys.debug("Initializing hotkey system")
                // Context: Ensures HotkeyService singleton initialization
                _ = HotkeyService.shared
            }
        }
        // Context: Hidden title bar provides cleaner preview window appearance
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
                previewManager: previewManager
            )
        }
    }
}
