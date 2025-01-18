/*
 Overlay/Settings/OverlaySettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct OverlaySettingsTab: View {
    // Private State
    @State private var showingWindowFocusInfo: Bool = false
    @State private var showingSourceTitleInfo: Bool = false

    // Focus Border Settings
    @AppStorage(OverlaySettingsKeys.focusBorderEnabled)
    private var focusBorderEnabled = OverlaySettingsKeys.defaults.focusBorderEnabled
    @AppStorage(OverlaySettingsKeys.focusBorderWidth)
    private var focusBorderWidth = OverlaySettingsKeys.defaults.focusBorderWidth
    @AppStorage(OverlaySettingsKeys.focusBorderColor)
    private var focusBorderColor = OverlaySettingsKeys.defaults.focusBorderColor

    // Source Title Settings
    @AppStorage(OverlaySettingsKeys.sourceTitleEnabled)
    private var sourceTitleEnabled = OverlaySettingsKeys.defaults.sourceTitleEnabled
    @AppStorage(OverlaySettingsKeys.sourceTitleFontSize)
    private var sourceTitleFontSize = OverlaySettingsKeys.defaults.sourceTitleFontSize
    @AppStorage(OverlaySettingsKeys.sourceTitleBackgroundOpacity)
    private var sourceTitleBackgroundOpacity = OverlaySettingsKeys.defaults
        .sourceTitleBackgroundOpacity
    @AppStorage(OverlaySettingsKeys.sourceTitleLocation)
    private var sourceTitleLocation = OverlaySettingsKeys.sourceTitleLocation

    var body: some View {
        Form {

            // MARK: - Focus Border Section

            Section {
                HStack {
                    Text("Window Focus")
                        .font(.headline)
                    InfoPopover(
                        content: .windowFocus,
                        isPresented: $showingWindowFocusInfo
                    )
                    Spacer()
                    Toggle("", isOn: $focusBorderEnabled)
                }
                .padding(.bottom, 4)

                if focusBorderEnabled {
                    HStack {
                        Text("Border width")
                        Spacer()
                        TextField(
                            "", value: $focusBorderWidth, formatter: NumberFormatter()
                        )
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        Text("px")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Border color")
                        Spacer()
                        ColorPicker("", selection: $focusBorderColor)
                    }
                }
            }

            // MARK: - Source Title Section

            Section {
                HStack {
                    Text("Source Title")
                        .font(.headline)
                    InfoPopover(
                        content: .sourceTitle,
                        isPresented: $showingSourceTitleInfo
                    )
                    Spacer()
                    Toggle("", isOn: $sourceTitleEnabled)
                }
                .padding(.bottom, 4)

                if sourceTitleEnabled {
                    HStack {
                        Text("Font size")
                        Spacer()
                        TextField(
                            "", value: $sourceTitleFontSize,
                            formatter: NumberFormatter()
                        )
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        Text("pt")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Opacity")
                        OpacitySlider(value: $sourceTitleBackgroundOpacity)
                        Text("\(Int(sourceTitleBackgroundOpacity * 100))%")
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }
                    HStack {
                        Picker("Location", selection: $sourceTitleLocation) {
                            Text("Upper").tag(true)
                            Text("Lower").tag(false)
                        }
                        .pickerStyle(.segmented)

                    }
                }
            }
        }
        .formStyle(.grouped)
        .animation(.easeInOut(duration: 0.3), value: focusBorderEnabled)
        .animation(.easeInOut(duration: 0.3), value: sourceTitleEnabled)
    }
}
