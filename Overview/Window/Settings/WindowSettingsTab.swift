/*
 Window/Settings/WindowSettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct WindowSettingsTab: View {
    // Private State
    @State private var showingAppearanceInfo: Bool = false
    @State private var showingVisibilityInfo: Bool = false
    @State private var showingManagementInfo: Bool = false

    // Window Settings
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
    @AppStorage(WindowSettingsKeys.assignPreviewsToAllDesktops)
    private var assignPreviewsToAllDesktops = WindowSettingsKeys.defaults
        .assignPreviewsToAllDesktops
    @AppStorage(WindowSettingsKeys.savePositionsOnClose)
    private var savePositionsOnClose = WindowSettingsKeys.defaults.savePositionsOnClose

    var body: some View {
        Form {

            // MARK: - Appearance Section

            Section {
                HStack {
                    Text("Appearance")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .windowAppearance,
                        isPresented: $showingAppearanceInfo
                    )
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
                        TextField(
                            "",
                            value: Binding(
                                get: { defaultWidth },
                                set: { newValue in
                                    defaultWidth = max(newValue, 160)
                                }
                            ), formatter: NumberFormatter()
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
                            "",
                            value: Binding(
                                get: { defaultHeight },
                                set: { newValue in
                                    defaultHeight = max(newValue, 80)
                                }
                            ), formatter: NumberFormatter()
                        )
                        .frame(width: 120)
                        .textFieldStyle(.roundedBorder)
                        Text("px")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // MARK: - Visibility Section

            Section {
                HStack {
                    Text("Visibility")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .windowVisibility,
                        isPresented: $showingVisibilityInfo
                    )
                }
                .padding(.bottom, 4)
                VStack {
                    Toggle("Show windows in Mission Control", isOn: $managedByMissionControl)
                    Toggle("Show windows on all desktops", isOn: $assignPreviewsToAllDesktops)
                }
            }

            // MARK: - Management Section

            Section {
                HStack {
                    Text("Management")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .windowManagement,
                        isPresented: $showingManagementInfo
                    )
                }
                .padding(.bottom, 4)
                VStack {
                    Toggle("Create window on launch", isOn: $createOnLaunch)
                    Toggle("Close window with preview source", isOn: $closeOnCaptureStop)
                    Toggle("Save window positions on quit", isOn: $savePositionsOnClose)
                }
            }
        }
        .formStyle(.grouped)
    }
}
