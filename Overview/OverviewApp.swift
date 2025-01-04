/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.
*/

import SwiftUI

@main
struct OverviewApp: App {
    @StateObject private var appSettings: AppSettings
    @StateObject private var hotkeyManager: HotkeyManager
    @StateObject private var previewManager: PreviewManager
    @StateObject private var windowManager: WindowManager

    init() {
        let preview = PreviewManager()
        let settings = AppSettings()
        let window = WindowManager()

        let hotkey = HotkeyManager(
            appSettings: settings,
            windowManager: window
        )

        self._appSettings = StateObject(wrappedValue: settings)
        self._hotkeyManager = StateObject(wrappedValue: hotkey)
        self._previewManager = StateObject(wrappedValue: preview)
        self._windowManager = StateObject(wrappedValue: window)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                appSettings: appSettings,
                previewManager: previewManager,
                windowManager: windowManager
            )
            .onChange(of: windowManager.focusedBundleId) { _, bundleId in
                previewManager.updateOverviewActive(focusedBundleId: bundleId)
            }
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
