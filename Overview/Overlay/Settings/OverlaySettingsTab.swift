/*
 Overlay/Settings/OverlaySettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import Defaults
import SwiftUI

struct OverlaySettingsTab: View {
    // Private State
    @State private var showingWindowFocusInfo: Bool = false
    @State private var showingSourceTitleInfo: Bool = false

    // Focus Border Settings
    @Default(.focusBorderEnabled) private var focusBorderEnabled
    @Default(.focusBorderWidth) private var focusBorderWidth
    @Default(.focusBorderColor) private var focusBorderColor

    // Source Title Settings
    @Default(.sourceTitleEnabled) private var sourceTitleEnabled
    @Default(.sourceTitleFontSize) private var sourceTitleFontSize
    @Default(.sourceTitleBackgroundOpacity) private var sourceTitleBackgroundOpacity
    @Default(.sourceTitleLocation) private var sourceTitleLocation
    @Default(.sourceTitleType) private var sourceTitleType

    var body: some View {
        Form {
            // MARK: - Focus Border Section
            Section {
                HStack {
                    Text("Source Focus")
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

                    HStack {
                        Picker("Type", selection: $sourceTitleType) {
                            Text("Window Title").tag(TitleType.windowTitle)
                            Text("Application Name").tag(TitleType.appName)
                            Text("Both").tag(TitleType.fullTitle)
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
