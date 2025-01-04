/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.
*/

import SwiftUI

@main
struct OverviewApp: App {
    @StateObject private var appSettings: AppSettings
    @StateObject private var windowManager: WindowManager
    @StateObject private var previewManager: PreviewManager
    @StateObject private var hotkeyManager: HotkeyManager

    init() {
        let settings = AppSettings()
        let window = WindowManager()
        let preview = PreviewManager(windowManager: window)
        let hotkey = HotkeyManager(
            appSettings: settings,
            windowManager: window
        )

        self._appSettings = StateObject(wrappedValue: settings)
        self._windowManager = StateObject(wrappedValue: window)
        self._previewManager = StateObject(wrappedValue: preview)
        self._hotkeyManager = StateObject(wrappedValue: hotkey)
    }

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
