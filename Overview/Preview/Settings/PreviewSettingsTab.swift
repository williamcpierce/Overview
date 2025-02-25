/*
 Preview/Settings/PreviewSettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct PreviewSettingsTab: View {
    // Dependencies
    private let availableFrameRates = PreviewSettingsKeys.defaults.availableCaptureFrameRates
    private let logger = AppLogger.settings

    // Private State
    @State private var showingFrameRateInfo: Bool = false
    @State private var showingAutoHidingInfo: Bool = false
    @State private var showingWindowFocusInfo: Bool = false
    @State private var showingSourceTitleInfo: Bool = false

    // Preview Settings
    @AppStorage(PreviewSettingsKeys.captureFrameRate)
    private var captureFrameRate = PreviewSettingsKeys.defaults.captureFrameRate
    @AppStorage(PreviewSettingsKeys.hideInactiveApplications)
    private var hideInactiveApplications = PreviewSettingsKeys.defaults.hideInactiveApplications
    @AppStorage(PreviewSettingsKeys.hideActiveWindow)
    private var hideActiveWindow = PreviewSettingsKeys.defaults.hideActiveWindow

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
    private var sourceTitleLocation = OverlaySettingsKeys.defaults.sourceTitleLocation
    @AppStorage(OverlaySettingsKeys.sourceTitleType)
    private var sourceTitleType = OverlaySettingsKeys.defaults.sourceTitleType

    var body: some View {
        Form {

            // MARK: - Frame Rate Section

            Section {
                HStack {
                    Text("Frame Rate")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .frameRate,
                        isPresented: $showingFrameRateInfo,
                        showWarning: captureFrameRate > 10.0
                    )
                }
                .padding(.bottom, 4)

                Picker("FPS", selection: $captureFrameRate) {
                    ForEach(availableFrameRates, id: \.self) { rate in
                        Text("\(Int(rate))").tag(rate)
                    }
                }
                .pickerStyle(.segmented)
            }

            // MARK: - Auto Hiding Section

            Section {
                HStack {
                    Text("Automatic Hiding")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .autoHiding,
                        isPresented: $showingAutoHidingInfo
                    )
                }
                .padding(.bottom, 4)

                VStack {
                    Toggle(
                        "Hide previews for inactive source applications",
                        isOn: $hideInactiveApplications
                    )

                    Toggle(
                        "Hide preview for focused source window",
                        isOn: $hideActiveWindow
                    )
                }
            }
            
            // MARK: - Focus Border Section

            Section {
                HStack {
                    Text("Window Focus Overlay")
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
                    Text("Source Title Overlay")
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
                            Text("Top").tag(true)
                            Text("Bottom").tag(false)
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
