/*
 Settings/Views/PreviewSettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import SwiftUI

struct PreviewSettingsTab: View {
    @ObservedObject var appSettings: AppSettings

    var body: some View {
        Form {
            // Opacity Section
            Section {
                Text("Opacity")
                    .font(.headline)
                    .padding(.bottom, 4)

                HStack(spacing: 8) {
                    OpacitySlider(value: $appSettings.previewOpacity)
                    Text("\(Int(appSettings.previewOpacity * 100))%")
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }
            }

            // Default Size Section
            Section {
                Text("Default Size")
                    .font(.headline)
                    .padding(.bottom, 4)

                HStack {
                    Text("Width")
                    Spacer()
                    TextField(
                        "", value: $appSettings.windowDefaultWidth, formatter: NumberFormatter()
                    )
                    .frame(width: 120)
                    .textFieldStyle(.roundedBorder)
                    Text("px")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Height")
                    Spacer()
                    TextField(
                        "", value: $appSettings.windowDefaultHeight, formatter: NumberFormatter()
                    )
                    .frame(width: 120)
                    .textFieldStyle(.roundedBorder)
                    Text("px")
                        .foregroundColor(.secondary)
                }
            }

            // Behavior Section
            Section {
                Text("Behavior")
                    .font(.headline)
                    .padding(.bottom, 4)

                Toggle("Show in Mission Control", isOn: $appSettings.windowManagedByMissionControl)
                Toggle(
                    "Close preview with source window", isOn: $appSettings.previewCloseOnCaptureStop
                )
                Toggle(
                    "Hide previews for inactive applications",
                    isOn: $appSettings.previewHideInactiveApplications)
                Toggle("Hide preview for active window", isOn: $appSettings.previewHideActiveWindow)
                Toggle(
                    "Enable alignment help in edit mode", isOn: $appSettings.windowAlignmentEnabled)
                Toggle("Enable window shadows", isOn: $appSettings.windowShadowEnabled)

                Text(
                    "Alignment help will cause preview windows to show behind some other windows until edit mode is turned off."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
