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
            GeneralSettingsTab(appSettings: appSettings)
                .tabItem { Label("General", systemImage: "gear") }
            
            PreviewSettingsTab(appSettings: appSettings)
                .tabItem { Label("Previews", systemImage: "macwindow") }
            
            PerformanceSettingsTab(appSettings: appSettings)
                .tabItem { Label("Performance", systemImage: "gauge.medium") }
            
            HotkeySettingsTab(appSettings: appSettings, sourceManager: sourceManager)
                .tabItem { Label("Hotkeys", systemImage: "command.square.fill") }
            
            FilterSettingsTab(appSettings: appSettings)
                .tabItem { Label("Filter", systemImage: "line.3.horizontal.decrease.circle.fill") }
        }
        .frame(width: 360, height: 450)
        .fixedSize()
        .background(.ultraThickMaterial)
    }
}
