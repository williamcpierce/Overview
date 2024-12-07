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
    @StateObject private var windowManager: WindowManager
    @StateObject private var appSettings = AppSettings()

    init() {
        let settings = AppSettings()
        self._appSettings = StateObject(wrappedValue: settings)
        self._windowManager = StateObject(wrappedValue: WindowManager(appSettings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(windowManager: windowManager, isEditModeEnabled: $windowManager.isEditModeEnabled, appSettings: appSettings)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .defaultSize(width: appSettings.defaultWindowWidth, height: appSettings.defaultWindowHeight)
        .commands {
            editCommands
        }
        
        Settings {
            SettingsView(appSettings: appSettings)
        }
    }
    
    private var editCommands: some Commands {
        CommandMenu("Edit") {
            Toggle("Edit Mode", isOn: $windowManager.isEditModeEnabled)
        }
    }
}
