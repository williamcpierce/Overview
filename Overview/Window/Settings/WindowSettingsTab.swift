/*
 Window/Settings/WindowSettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import Defaults
import SwiftUI

struct WindowSettingsTab: View {
    // Private State
    @State private var showingAppearanceInfo: Bool = false
    @State private var showingVisibilityInfo: Bool = false
    @State private var showingManagementInfo: Bool = false

    // Window Settings
    @Default(.windowOpacity) private var windowOpacity
    @Default(.windowShadowEnabled) private var shadowEnabled
    @Default(.defaultWindowWidth) private var defaultWindowWidth
    @Default(.defaultWindowHeight) private var defaultWindowHeight
    @Default(.syncAspectRatio) private var syncAspectRatio
    @Default(.managedByMissionControl) private var managedByMissionControl
    @Default(.createOnLaunch) private var createOnLaunch
    @Default(.closeOnCaptureStop) private var closeOnCaptureStop
    @Default(.assignPreviewsToAllDesktops) private var assignPreviewsToAllDesktops
    @Default(.saveWindowsOnQuit) private var saveWindowsOnQuit
    @Default(.restoreWindowsOnLaunch) private var restoreWindowsOnLaunch

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
                    OpacitySlider(value: $windowOpacity)
                    Text("\(Int(windowOpacity * 100))%")
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }

                VStack {
                    HStack {
                        Text("Default width")
                        Spacer()
                        TextField(
                            "",
                            value: Binding(
                                get: { defaultWindowWidth },
                                set: { newValue in
                                    defaultWindowWidth = max(newValue, 80)
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
                                get: { defaultWindowHeight },
                                set: { newValue in
                                    defaultWindowHeight = max(newValue, 40)
                                }
                            ), formatter: NumberFormatter()
                        )
                        .frame(width: 120)
                        .textFieldStyle(.roundedBorder)
                        Text("px")
                            .foregroundColor(.secondary)
                    }
                }

                Toggle("Shadows", isOn: $shadowEnabled)

                Toggle("Synchronize aspect ratio", isOn: $syncAspectRatio)
            }

            // MARK: - System Visibility Section

            Section {
                HStack {
                    Text("System Visibility")
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

            // MARK: - Window Management Section

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
                    Toggle("Always create window on launch", isOn: $createOnLaunch)
                    Toggle("Close window with preview source", isOn: $closeOnCaptureStop)
                    Toggle("Save window positions on quit", isOn: $saveWindowsOnQuit)
                    Toggle("Restore window positions on launch", isOn: $restoreWindowsOnLaunch)
                }
            }
        }
        .formStyle(.grouped)
    }
}
