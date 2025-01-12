/*
 Settings/Views/PreviewSettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import SwiftUI

struct PreviewSettingsTab: View {
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
        Section {
            HStack {
                Text("Frame Rate")
                    .font(.headline)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }

            Picker("FPS", selection: $appSettings.captureFrameRate) {
                ForEach(appSettings.availableCaptureFrameRates, id: \.self) { rate in
                    Text("\(Int(rate))").tag(rate)
                }
            }
            .pickerStyle(.segmented)
        }

        Section {
            HStack {
                Text("Automatic Hiding")
                    .font(.headline)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            VStack {
                HStack {
                    Toggle(
                        "Hide inactive app previews",
                        isOn: $appSettings.previewHideInactiveApplications)
                    Spacer()
                }
                HStack {
                    Toggle("Hide active window preview", isOn: $appSettings.previewHideActiveWindow)
                    Spacer()
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
