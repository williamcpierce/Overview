/*
 Settings/SettingsView.swift
 Overview

 Created by William Pierce on 10/13/24.

 Provides the main settings interface for the application, organizing configuration
 options into logical tab groups for general settings, window behavior, performance,
 hotkeys, and filtering options.
*/

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var sourceManager: SourceManager
    private let logger = AppLogger.settings

    var body: some View {
        TabView {
            PreviewSettingsTab(appSettings: appSettings)
                .tabItem { Label("Preview", systemImage: "rectangle.dashed.badge.record") }

            WindowSettingsTab(appSettings: appSettings)
                .tabItem { Label("Window", systemImage: "macwindow") }

            OverlaySettingsTab(appSettings: appSettings)
                .tabItem { Label("Overlay", systemImage: "square.2.layers.3d.bottom.filled") }

            HotkeySettingsTab(appSettings: appSettings, sourceManager: sourceManager)
                .tabItem { Label("Hotkey", systemImage: "command.square.fill") }

            FilterSettingsTab(appSettings: appSettings)
                .tabItem { Label("Filter", systemImage: "line.3.horizontal.decrease.circle.fill") }
        }
        .frame(width: 320, height: 380)
        .fixedSize()
        .background(.ultraThickMaterial)
        .onAppear {
            let settingsStyleMask: NSWindow.StyleMask.RawValue = 32771
            if let settingsWindow = NSApp.windows.first(where: { $0.styleMask.rawValue == settingsStyleMask }) {
                settingsWindow.level = .statusBar + 2
            }
        }
    }
}
