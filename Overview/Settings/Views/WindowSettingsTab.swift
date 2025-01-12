/*
 Settings/Views/WindowSettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import SwiftUI

struct WindowSettingsTab: View {
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
        Section {
            HStack {
                Text("Appearance")
                    .font(.headline)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            VStack {
                HStack(spacing: 8) {
                    VStack {
                        Text("Opacity")
                    }
                    OpacitySlider(value: $appSettings.previewOpacity)
                    Text("\(Int(appSettings.previewOpacity * 100))%")
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }

                HStack {
                    Toggle("Shadows", isOn: $appSettings.windowShadowEnabled)
                    Spacer()
                }
            }
            VStack {
                HStack {
                    Text("Default width")
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
                    Text("Default height")
                    Spacer()
                    TextField(
                        "", value: $appSettings.windowDefaultHeight, formatter: NumberFormatter()
                    ).frame(width: 120)
                        .textFieldStyle(.roundedBorder)
                    Text("px")
                        .foregroundColor(.secondary)
                }
            }
        }

        Section {
            HStack {
                Text("Behavior")
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
                        "Show in Mission Control", isOn: $appSettings.windowManagedByMissionControl)
                    Spacer()
                }
                HStack {
                    Toggle(
                        "Create window on launch", isOn: $appSettings.windowCreateOnLaunch)
                    Spacer()
                }
                HStack {
                    Toggle(
                        "Close with preview source", isOn: $appSettings.previewCloseOnCaptureStop
                    )
                    Spacer()
                }
                HStack {
                    Toggle(
                        "Enable alignment help", isOn: $appSettings.windowAlignmentEnabled)
                    Spacer()
                }
            }
        }
    }
}
