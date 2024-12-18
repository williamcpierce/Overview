/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 Main application entry point that manages the app lifecycle, window configuration,
 and global state initialization. Serves as the root coordinator for all major
 app components, handling window presentation and global keyboard shortcuts.
*/

import SwiftUI

/// Configures and coordinates the application's core services and window presentation.
/// Provides the central initialization point for global application state and window management.
///
/// Thread safety: Must be initialized on the main thread
@main
struct OverviewApp: App {
    @StateObject private var previewManager: PreviewManager
    @StateObject private var appSettings: AppSettings
    @StateObject private var hotkeyManager: HotkeyManager

    init() {
        let settings = AppSettings()
        let preview = PreviewManager(appSettings: settings)

        // WindowManager singleton must be initialized before HotkeyManager
        _ = WindowManager.shared

        self._appSettings = StateObject(wrappedValue: settings)
        self._previewManager = StateObject(wrappedValue: preview)
        self._hotkeyManager = StateObject(wrappedValue: HotkeyManager())

        initializeStoredHotkeys(settings)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                previewManager: previewManager,
                isEditModeEnabled: $previewManager.isEditModeEnabled,
                appSettings: appSettings
            )
            .onAppear(perform: initializeHotkeySystem)
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

        Settings {
            SettingsView(
                appSettings: appSettings,
                previewManager: previewManager
            )
        }
    }

    private func initializeHotkeySystem() {
        _ = HotkeyService.shared
    }

    private func initializeStoredHotkeys(_ settings: AppSettings) {
        do {
            try HotkeyService.shared.registerHotkeys(settings.hotkeyBindings)
        } catch {
            AppLogger.settings.error("Failed to register hotkeys: \(error.localizedDescription)")
        }
    }
}
