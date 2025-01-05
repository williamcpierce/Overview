/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 The main application entry point that configures and coordinates core services,
 manages the application lifecycle, and sets up the primary user interface.
*/

import SwiftUI

@main
struct OverviewApp: App {
    // MARK: - Core Services

    @StateObject private var appSettings: AppSettings
    @StateObject private var windowManager: WindowManager
    @StateObject private var previewManager: PreviewManager
    @StateObject private var hotkeyManager: HotkeyManager

    private let logger = AppLogger.interface

    // MARK: - Initialization

    init() {
        logger.debug("Initializing core application services")

        let settings = AppSettings()
        let window = WindowManager(appSettings: settings)
        let preview = PreviewManager(windowManager: window)
        let hotkey = HotkeyManager(
            appSettings: settings,
            windowManager: window
        )

        self._appSettings = StateObject(wrappedValue: settings)
        self._windowManager = StateObject(wrappedValue: window)
        self._previewManager = StateObject(wrappedValue: preview)
        self._hotkeyManager = StateObject(wrappedValue: hotkey)

        logger.info("Application services initialized successfully")
    }

    // MARK: - Scene Configuration

    var body: some Scene {
        WindowGroup {
            ContentView(
                appSettings: appSettings,
                previewManager: previewManager,
                windowManager: windowManager
            )
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .defaultSize(
            width: appSettings.defaultWindowWidth,
            height: appSettings.defaultWindowHeight
        )
        .commands {
            CommandMenu("Edit") {
                Toggle("Edit Mode", isOn: $previewManager.editModeEnabled)
            }
        }

        Settings {
            SettingsView(
                appSettings: appSettings,
                windowManager: windowManager
            )
        }
    }
}
