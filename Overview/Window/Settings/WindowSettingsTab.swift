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
    @Default(.defaultWindowWidth) private var defaultWindowWidth
    @Default(.defaultWindowHeight) private var defaultWindowHeight

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

                Defaults.Toggle("Shadows", key: .windowShadowEnabled)
                Defaults.Toggle("Synchronize aspect ratio", key: .syncAspectRatio)
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
                    Defaults.Toggle(
                        "Show windows in Mission Control", key: .managedByMissionControl)
                    Defaults.Toggle(
                        "Show windows on all desktops", key: .assignPreviewsToAllDesktops)
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
                    Defaults.Toggle("Always create window on launch", key: .createOnLaunch)
                    Defaults.Toggle("Close window with preview source", key: .closeOnCaptureStop)
                    Defaults.Toggle("Save window positions on quit", key: .saveWindowsOnQuit)
                    Defaults.Toggle(
                        "Restore window positions on launch", key: .restoreWindowsOnLaunch)
                }
            }
        }
        .formStyle(.grouped)
    }
}
