/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 Main application entry point that manages the app lifecycle global state
 initialization. Serves as the root coordinator for all major app components.
*/

import SwiftUI

@main
struct OverviewApp: App {
    @StateObject private var appSettings: AppSettings
    @StateObject private var previewManager: PreviewManager
    @StateObject private var windowManager: WindowManager
    @StateObject private var hotkeyManager: HotkeyManager

    init() {
        let settings = AppSettings()
        let preview = PreviewManager()
        let window = WindowManager()
        let hotkey = HotkeyManager(
            appSettings: settings,
            windowManager: window
        )

        self._appSettings = StateObject(wrappedValue: settings)
        self._previewManager = StateObject(wrappedValue: preview)
        self._windowManager = StateObject(wrappedValue: window)
        self._hotkeyManager = StateObject(wrappedValue: hotkey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                appSettings: appSettings,
                previewManager: previewManager
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
