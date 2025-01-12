/*
 Settings/Views/OverlaySettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import SwiftUI

struct OverlaySettingsTab: View {
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
                Text("Window Focus")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $appSettings.focusBorderEnabled)
            }
            if appSettings.focusBorderEnabled {
                VStack {
                    HStack {
                        Text("Border width")
                        Spacer()
                        TextField(
                            "", value: $appSettings.focusBorderWidth, formatter: NumberFormatter()
                        )
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        Text("px")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Border color")
                        Spacer()
                        ColorPicker("", selection: $appSettings.focusBorderColor)
                    }
                }
            }
        }

        Section {
            HStack {
                Text("Source Title")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $appSettings.sourceTitleEnabled)
            }
            if appSettings.sourceTitleEnabled {
                VStack {
                    HStack {
                        Text("Font size")
                        Spacer()
                        TextField(
                            "", value: $appSettings.sourceTitleFontSize,
                            formatter: NumberFormatter()
                        )
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        Text("pt")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        VStack {
                            Text("Opacity")
                        }
                        OpacitySlider(value: $appSettings.sourceTitleBackgroundOpacity)
                        Text("\(Int(appSettings.sourceTitleBackgroundOpacity * 100))%")
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }
                }
            }
        }
    }
}
