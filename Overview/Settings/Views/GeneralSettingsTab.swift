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
        if #available(macOS 13.0, *) {
            Form {
                formContent
            }
            .formStyle(.grouped)
            .safeAreaInset(edge: .bottom) {
                Button("Reset All Settings") {
                    logger.debug("Settings reset requested")
                    showingResetAlert = true
                }
                .padding(.bottom, 10)
            }
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    formContent
                }
                .padding()
                .safeAreaInset(edge: .bottom) {
                    Button("Reset All Settings") {
                        logger.debug("Settings reset requested")
                        showingResetAlert = true
                    }
                    .padding(.bottom, 10)
                }
            }
        }
    }

    @ViewBuilder
    private var formContent: some View {
        // Focus Border Section
        Section {
            Text("Border Overlay")
                .font(.headline)
                .padding(.bottom, 4)
            HStack {
                Toggle("Show focused window border", isOn: $appSettings.focusBorderEnabled)
                Spacer()
            }
        
            if appSettings.focusBorderEnabled {
                HStack {
                    Text("Border width")
                    Spacer()
                    TextField(
                        "", value: $appSettings.focusBorderWidth, formatter: NumberFormatter()
                    )
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    Text("pt")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Border color")
                    Spacer()
                    ColorPicker("", selection: $appSettings.focusBorderColor)
                }
            }
        }

        // Title Overlay Section
        Section {
            Text("Title Overlay")
                .font(.headline)
                .padding(.bottom, 4)
            HStack {
                Toggle("Show window title", isOn: $appSettings.sourceTitleEnabled)
                Spacer()
            }
            
            if appSettings.sourceTitleEnabled {
                HStack {
                    Text("Font size")
                    Spacer()
                    TextField(
                        "", value: $appSettings.sourceTitleFontSize,
                        formatter: NumberFormatter()
                    )
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
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                logger.info("Performing settings reset")
                appSettings.resetToDefaults()
            }
        }
    }
}
