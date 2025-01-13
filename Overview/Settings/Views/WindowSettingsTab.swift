/*
 Settings/Views/WindowSettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct WindowSettingsTab: View {
    // MARK: - Window Settings
    @AppStorage(WindowSettingsKeys.previewOpacity)
    private var previewOpacity = WindowSettingsKeys.defaults.previewOpacity

    @AppStorage(WindowSettingsKeys.shadowEnabled)
    private var shadowEnabled = WindowSettingsKeys.defaults.shadowEnabled

    @AppStorage(WindowSettingsKeys.defaultWidth)
    private var defaultWidth = WindowSettingsKeys.defaults.defaultWidth

    @AppStorage(WindowSettingsKeys.defaultHeight)
    private var defaultHeight = WindowSettingsKeys.defaults.defaultHeight

    @AppStorage(WindowSettingsKeys.managedByMissionControl)
    private var managedByMissionControl = WindowSettingsKeys.defaults.managedByMissionControl

    @AppStorage(WindowSettingsKeys.createOnLaunch)
    private var createOnLaunch = WindowSettingsKeys.defaults.createOnLaunch

    @AppStorage(WindowSettingsKeys.closeOnCaptureStop)
    private var closeOnCaptureStop = WindowSettingsKeys.defaults.closeOnCaptureStop

    @AppStorage(WindowSettingsKeys.alignmentEnabled)
    private var alignmentEnabled = WindowSettingsKeys.defaults.alignmentEnabled

    var body: some View {
        Form {

            // MARK: - Appearance Section

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
                .padding(.bottom, 4)

                HStack(spacing: 8) {
                    Text("Opacity")
                    OpacitySlider(value: $previewOpacity)
                    Text("\(Int(previewOpacity * 100))%")
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }

                Toggle("Shadows", isOn: $shadowEnabled)
                VStack {
                    HStack {
                        Text("Default width")
                        Spacer()
                        TextField("", value: $defaultWidth, formatter: NumberFormatter())
                            .frame(width: 120)
                            .textFieldStyle(.roundedBorder)
                        Text("px")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Default height")
                        Spacer()
                        TextField("", value: $defaultHeight, formatter: NumberFormatter())
                            .frame(width: 120)
                            .textFieldStyle(.roundedBorder)
                        Text("px")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // MARK: - Behavior Section
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
                .padding(.bottom, 4)
                VStack {
                    Toggle("Show in Mission Control", isOn: $managedByMissionControl)
                    Toggle("Create window on launch", isOn: $createOnLaunch)
                    Toggle("Close with preview source", isOn: $closeOnCaptureStop)
                    Toggle("Enable alignment help", isOn: $alignmentEnabled)
                }
            }
        }
        .formStyle(.grouped)
    }
}
