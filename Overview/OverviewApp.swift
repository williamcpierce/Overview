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

@main
struct OverviewApp: App {
    @StateObject private var previewManager: PreviewManager
    @StateObject private var appSettings: AppSettings
    @StateObject private var hotkeyManager: HotkeyManager

    init() {
        let settings = AppSettings()
        let preview = PreviewManager(appSettings: settings)

        _ = WindowManager.shared

        self._appSettings = StateObject(wrappedValue: settings)
        self._previewManager = StateObject(wrappedValue: preview)
        self._hotkeyManager = StateObject(wrappedValue: HotkeyManager())

        HotkeyService.shared.registerHotkeys(settings.hotkeyBindings)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                previewManager: previewManager,
                isEditModeEnabled: $previewManager.isEditModeEnabled,
                appSettings: appSettings
            )
            .onAppear {
                _ = HotkeyService.shared
            }
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
}
