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
    @ObservedObject var hotkeyStorage: HotkeyStorage
    @ObservedObject var sourceManager: SourceManager
    @StateObject private var settingsManager: SettingsManager
    private let logger = AppLogger.settings

    init(hotkeyStorage: HotkeyStorage, sourceManager: SourceManager) {
        self.hotkeyStorage = hotkeyStorage
        self.sourceManager = sourceManager
        self._settingsManager = StateObject(
            wrappedValue: SettingsManager(hotkeyStorage: hotkeyStorage))
    }

    var body: some View {
        TabView {
            PreviewSettingsTab()
                .tabItem { Label("Preview", systemImage: "rectangle.dashed.badge.record") }

            WindowSettingsTab()
                .tabItem { Label("Window", systemImage: "macwindow") }

            OverlaySettingsTab()
                .tabItem { Label("Overlay", systemImage: "square.2.layers.3d.bottom.filled") }

            HotkeySettingsTab(hotkeyStorage: hotkeyStorage, sourceManager: sourceManager)
                .tabItem { Label("Hotkey", systemImage: "command.square.fill") }

            FilterSettingsTab(settingsManager: settingsManager)
                .tabItem { Label("Filter", systemImage: "line.3.horizontal.decrease.circle.fill") }
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                Divider()
                ResetSettingsButton(settingsManager: settingsManager)
            }
            .padding(.bottom, 8)
            .background(.background)
        }
        .frame(width: 324, height: 420)
        .fixedSize()
        .background(.ultraThickMaterial)
        .onAppear {
            let settingsStyleMask: NSWindow.StyleMask.RawValue = 32771
            if let settingsWindow = NSApp.windows.first(where: {
                $0.styleMask.rawValue == settingsStyleMask
            }) {
                settingsWindow.level = .statusBar + 2
            }
        }
    }
}
