/*
 Settings/Views/GeneralSettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import SwiftUI

struct GeneralSettingsTab: View {
    @ObservedObject var appSettings: AppSettings
    @State private var showingResetAlert = false
    private let logger = AppLogger.settings
    
    var body: some View {
        Form {
            // Focus Border Section
            Section {
                Text("Border Overlay")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Toggle("Show focused window border", isOn: $appSettings.focusBorderEnabled)
                
                if appSettings.focusBorderEnabled {
                    HStack {
                        Text("Border width")
                        Spacer()
                        TextField("", value: $appSettings.focusBorderWidth, formatter: NumberFormatter())
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Text("pt")
                            .foregroundColor(.secondary)
                    }
                    ColorPicker("Border color", selection: $appSettings.focusBorderColor)
                }
            }
            
            // Title Overlay Section
            Section {
                Text("Title Overlay")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Toggle("Show window title", isOn: $appSettings.sourceTitleEnabled)
                
                if appSettings.sourceTitleEnabled {
                    HStack {
                        Text("Font size")
                        Spacer()
                        TextField("", value: $appSettings.sourceTitleFontSize, formatter: NumberFormatter())
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Text("pt")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        HStack {
                            Text("Background opacity")
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            OpacitySlider(value: $appSettings.sourceTitleBackgroundOpacity)
                            Text("\(Int(appSettings.sourceTitleBackgroundOpacity * 100))%")
                                .foregroundColor(.secondary)
                                .frame(width: 40)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            Button("Reset All Settings") {
                logger.debug("Settings reset requested")
                showingResetAlert = true
            }
            .padding(.bottom, 10)
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                logger.info("Performing settings reset")
                appSettings.resetToDefaults()
            }
        }
    }
}
