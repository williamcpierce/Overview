/*
 Settings/Views/PreviewSettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import SwiftUI

struct PreviewSettingsTab: View {
    @ObservedObject var appSettings: AppSettings

    var body: some View {
        if #available(macOS 13.0, *) {
            Form {
                formContent
            }
            .formStyle(.grouped)
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    formContent
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var formContent: some View {
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

            HStack {
                Toggle("Show in Mission Control", isOn: $appSettings.windowManagedByMissionControl)
                Spacer()
            }
            HStack {
                Toggle(
                    "Close preview with source window", isOn: $appSettings.previewCloseOnCaptureStop
                )
                Spacer()
            }
            HStack {
                Toggle(
                    "Hide previews for inactive applications",
                    isOn: $appSettings.previewHideInactiveApplications)
                Spacer()
            }
            HStack {
                Toggle("Hide preview for active window", isOn: $appSettings.previewHideActiveWindow)
                Spacer()
            }
            HStack {
                Toggle("Enable window shadows", isOn: $appSettings.windowShadowEnabled)
                Spacer()
            }
            HStack {
                Toggle(
                "Create preview on app launch", isOn: $appSettings.windowCreateOnLaunch)
                Spacer()
            }
            HStack {
                Toggle(
                    "Enable alignment help in edit mode", isOn: $appSettings.windowAlignmentEnabled)
                Spacer()
            }
            Text(
                "Alignment help will cause preview windows to show behind some other windows until edit mode is turned off."
            )
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}
