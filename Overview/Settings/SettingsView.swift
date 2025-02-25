/*
 Settings/SettingsView.swift
 Overview

 Created by William Pierce on 10/13/24.

 Provides the main settings interface for the application, organizing configuration
 options into logical tab groups for general settings, window behavior, performance,
 shortcut, and filtering options.
*/

import Sparkle
import SwiftUI

struct SettingsView: View {
    // Dependencies
    @ObservedObject var sourceManager: SourceManager
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var updateManager: UpdateManager
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var layoutManager: LayoutManager
    private let logger = AppLogger.settings

    init(
        sourceManager: SourceManager,
        settingsManager: SettingsManager,
        updateManager: UpdateManager,
        windowManager: WindowManager,
        layoutManager: LayoutManager

    ) {
        self.sourceManager = sourceManager
        self.settingsManager = settingsManager
        self.updateManager = updateManager
        self.windowManager = windowManager
        self.layoutManager = layoutManager
    }

    var body: some View {
        TabView {
            PreviewSettingsTab()
                .tabItem { Label("Previews", systemImage: "record.circle") }
                .scrollDisabled(true)

            WindowSettingsTab()
                .tabItem { Label("Windows", systemImage: "macwindow") }
                .scrollDisabled(true)

            LayoutSettingsTab(windowManager: windowManager, layoutManager: layoutManager)
                .tabItem { Label("Layouts", systemImage: "rectangle.3.offgrid.fill") }
                .frame(minHeight: 288, maxHeight: 504)

            ShortcutSettingsTab()
                .tabItem { Label("Shortcuts", systemImage: "command.square.fill") }
                .frame(minHeight: 288, maxHeight: 504)

            SourceSettingsTab(settingsManager: settingsManager)
                .tabItem { Label("Sources", systemImage: "line.3.horizontal.decrease.circle.fill") }
                .frame(minHeight: 288, maxHeight: 504)

            UpdateSettingsTab(updateManager: updateManager)
                .tabItem { Label("Updates", systemImage: "arrow.clockwise.circle.fill") }
                .scrollDisabled(true)
        }
        .background(.ultraThickMaterial)
        .safeAreaInset(edge: .bottom) {
            VStack {
                Divider()
                ResetSettingsButton(settingsManager: settingsManager)
            }
            .padding(.bottom, 8)
            .background(.regularMaterial)
        }
        .frame(width: 384)
        .fixedSize()

        // MARK: - Settings Window Level

        .onAppear {
            let settingsStyleMask: NSWindow.StyleMask.RawValue = 32771
            if let settingsWindow = NSApp.windows.first(where: {
                $0.styleMask.rawValue == settingsStyleMask
            }) {
                settingsWindow.level = .statusBar + 2
                settingsWindow.collectionBehavior = [.managed]
            }
        }
    }
}
