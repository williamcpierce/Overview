/*
 Settings/GeneralSettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct GeneralSettingsTab: View {
    // Dependencies
    private let availableFrameRates = PreviewSettingsKeys.defaults.availableCaptureFrameRates
    private let logger = AppLogger.settings

    // Private State
    @State private var showingFrameRateInfo: Bool = false
    @State private var showingAutoHidingInfo: Bool = false
    @State private var showingOverlaySettings: Bool = false

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
                    Text("Preview Frame Rate")
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
                    Text("Automatic Preview Hiding")
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
            HStack {
                Spacer()
                Button("Overlay Settings...") {
                    showingOverlaySettings = true
                }
                .sheet(isPresented: $showingOverlaySettings) {
                    OverlaySettingsView(
                        focusBorderEnabled: $focusBorderEnabled,
                        focusBorderWidth: $focusBorderWidth,
                        focusBorderColor: $focusBorderColor,
                        sourceTitleEnabled: $sourceTitleEnabled,
                        sourceTitleFontSize: $sourceTitleFontSize,
                        sourceTitleBackgroundOpacity: $sourceTitleBackgroundOpacity,
                        sourceTitleLocation: $sourceTitleLocation,
                        sourceTitleType: $sourceTitleType
                    )
                    .frame(width: 360, height: 432)
                    .presentationDetents([.height(432)])
                    .scrollDisabled(true)
                }
            }
            .padding(.top, 4)
        }
        .formStyle(.grouped)
    }
}

struct OverlaySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Private State
    @State private var showingWindowFocusInfo: Bool = false
    @State private var showingSourceTitleInfo: Bool = false
    
    // Focus Border Settings Bindings
    @Binding var focusBorderEnabled: Bool
    @Binding var focusBorderWidth: Double
    @Binding var focusBorderColor: Color
    
    // Source Title Settings Bindings
    @Binding var sourceTitleEnabled: Bool
    @Binding var sourceTitleFontSize: Double
    @Binding var sourceTitleBackgroundOpacity: Double
    @Binding var sourceTitleLocation: Bool
    @Binding var sourceTitleType: String
    
    var body: some View {
        NavigationView {
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
            .navigationTitle("Overlay Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .frame(minWidth: 360, idealHeight: 432)
        }
    }
}
