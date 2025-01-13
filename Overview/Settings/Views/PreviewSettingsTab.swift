/*
 Settings/Views/PreviewSettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct PreviewSettingsTab: View {
    // MARK: - Preview Settings
    @AppStorage(PreviewSettingsKeys.captureFrameRate)
    private var captureFrameRate = PreviewSettingsKeys.defaults.captureFrameRate

    @AppStorage(PreviewSettingsKeys.hideInactiveApplications)
    private var hideInactiveApplications = PreviewSettingsKeys.defaults.hideInactiveApplications

    @AppStorage(PreviewSettingsKeys.hideActiveWindow)
    private var hideActiveWindow = PreviewSettingsKeys.defaults.hideActiveWindow

    @State private var showingResetAlert = false
    private let logger = AppLogger.settings
    private let availableFrameRates = PreviewSettingsKeys.defaults.availableCaptureFrameRates

    var body: some View {
        Form {
            // Frame Rate Section
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
                .padding(.bottom, 4)

                Picker("FPS", selection: $captureFrameRate) {
                    ForEach(availableFrameRates, id: \.self) { rate in
                        Text("\(Int(rate))").tag(rate)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Auto Hiding Section
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
                .padding(.bottom, 4)

                VStack {
                    Toggle(
                        "Hide inactive app previews",
                        isOn: $hideInactiveApplications
                    )

                    Toggle(
                        "Hide active window preview",
                        isOn: $hideActiveWindow
                    )
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
                resetToDefaults()
            }
        }
    }

    private func resetToDefaults() {
        captureFrameRate = PreviewSettingsKeys.defaults.captureFrameRate
        hideInactiveApplications = PreviewSettingsKeys.defaults.hideInactiveApplications
        hideActiveWindow = PreviewSettingsKeys.defaults.hideActiveWindow
    }
}
