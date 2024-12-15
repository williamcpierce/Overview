/*
 SettingsView.swift
 Overview

 Created by William Pierce on 10/13/24.

 Provides the settings interface for Overview, managing user preferences through
 a tabbed view system that handles all aspects of window preview behavior.
 Coordinates real-time updates of capture configuration and window management.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Manages application settings through a tabbed interface that updates in real-time
///
/// Key responsibilities:
/// - Presents user preferences in organized, themed tab groups
/// - Validates and constrains settings within acceptable ranges
/// - Provides immediate visual feedback for setting changes
/// - Maintains persistent storage of user preferences
/// - Manages hotkey binding configuration and removal
///
/// Coordinates with:
/// - AppSettings: Stores and manages setting values
/// - PreviewView: Updates preview appearance in real-time
/// - PreviewAccessor: Applies preview window behavior changes
/// - CaptureManager: Updates capture configuration
/// - HotkeyManager: Processes keyboard shortcut configurations
struct SettingsView: View {
    // MARK: - Properties

    /// Application settings and preferences manager
    /// - Note: Changes propagate immediately to all views
    @ObservedObject var appSettings: AppSettings

    /// Coordinates window preview state and lifecycle
    @ObservedObject var previewManager: PreviewManager

    /// Controls visibility of hotkey binding sheet
    @State private var isAddingHotkey = false

    /// Controls visibility of settings reset confirmation
    @State private var showingResetAlert = false

    /// Available frame rate options in frames per second
    /// - Note: Options balance preview smoothness with resource usage
    private let frameRateOptions = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]

    // MARK: - View Layout

    var body: some View {
        TabView {
            generalTab
            windowTab
            performanceTab
            experimentTab
        }
        .frame(width: 360, height: 430)
    }

    // MARK: - Private Views

    /// General settings for basic overlay preferences and keyboard shortcuts
    /// - Note: Controls visibility of UI elements in preview windows
    private var generalTab: some View {
        Form {
            // Border configuration section
            Section {
                Text("Border Overlay")
                    .font(.headline)
                    .padding(.bottom, 4)

                Toggle("Show focused window border", isOn: $appSettings.showFocusedBorder)
                    .onChange(of: appSettings.showFocusedBorder) { oldValue, newValue in
                        AppLogger.settings.info("Window border visibility changed: \(newValue)")
                    }

                if appSettings.showFocusedBorder {
                    HStack {
                        Text("Border width")
                        Spacer()
                        TextField(
                            "", value: $appSettings.focusBorderWidth,
                            formatter: NumberFormatter()
                        )
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        Text("pt")
                            .foregroundColor(.secondary)
                    }
                    ColorPicker("Border color", selection: $appSettings.focusBorderColor)
                }
            }

            // Title configuration section
            Section {
                Text("Title Overlay")
                    .font(.headline)
                    .padding(.bottom, 4)

                Toggle("Show window title", isOn: $appSettings.showWindowTitle)
                    .onChange(of: appSettings.showWindowTitle) { oldValue, newValue in
                        AppLogger.settings.info("Window title visibility changed: \(newValue)")
                    }

                if appSettings.showWindowTitle {
                    HStack {
                        Text("Font size")
                        Spacer()
                        TextField(
                            "", value: $appSettings.titleFontSize, formatter: NumberFormatter()
                        )
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        Text("pt")
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        HStack {
                            Text("Background opacity")
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            SliderRepresentable(
                                value: $appSettings.titleBackgroundOpacity,
                                minValue: 0.0,
                                maxValue: 1.0
                            )
                            Text("\(Int(appSettings.titleBackgroundOpacity * 100))%")
                                .foregroundColor(.secondary)
                                .frame(width: 40)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("General", systemImage: "gear") }
        .safeAreaInset(edge: .bottom) {
            Button("Reset All Settings") {
                showingResetAlert = true
            }
            .padding(.bottom, 8)
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text(
                "This will reset all settings to their default values. This action cannot be undone."
            )
        }
    }

    /// Window configuration for appearance and behavior settings
    /// - Note: Controls window transparency, size, and system integration
    private var windowTab: some View {
        Form {
            // Window opacity section
            Section {
                Text("Opacity")
                    .font(.headline)
                    .padding(.bottom, 4)

                HStack(spacing: 8) {
                    SliderRepresentable(
                        value: $appSettings.opacity,
                        minValue: 0.05,
                        maxValue: 1.0
                    )
                    .onChange(of: appSettings.opacity) { oldValue, newValue in
                        AppLogger.settings.info("Window opacity updated: \(Int(newValue * 100))%")
                    }

                    Text("\(Int(appSettings.opacity * 100))%")
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }
            }

            // Default window dimensions section
            Section {
                Text("Default Size")
                    .font(.headline)
                    .padding(.bottom, 4)

                ForEach(
                    [
                        ("Width", $appSettings.defaultWindowWidth),
                        ("Height", $appSettings.defaultWindowHeight),
                    ], id: \.0
                ) { label, binding in
                    HStack {
                        Text("\(label)")
                        Spacer()
                        TextField("", value: binding, formatter: NumberFormatter())
                            .frame(width: 120)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: binding.wrappedValue) { oldValue, newValue in
                                AppLogger.settings.info(
                                    "Default window \(label.lowercased()) changed: \(newValue)px")
                            }
                        Text("px")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Window management section
            Section {
                Text("Behavior")
                    .font(.headline)
                    .padding(.bottom, 4)

                Toggle("Show in Mission Control", isOn: $appSettings.managedByMissionControl)
                    .onChange(of: appSettings.managedByMissionControl) { oldValue, newValue in
                        AppLogger.settings.info("Mission Control integration changed: \(newValue)")
                    }

                Toggle(
                    "Enable alignment help in edit mode",
                    isOn: $appSettings.enableEditModeAlignment
                )
                .onChange(of: appSettings.enableEditModeAlignment) { oldValue, newValue in
                    AppLogger.settings.info("Edit mode alignment changed: \(newValue)")
                }

                Text(
                    "Alignment help will cause preview windows to show behind some other windows until edit mode is turned off."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Previews", systemImage: "macwindow") }
    }

    /// Performance settings for frame rate configuration
    /// - Note: Controls preview update frequency and resource usage
    private var performanceTab: some View {
        Form {
            Section {
                Text("Frame Rate")
                    .font(.headline)
                    .padding(.bottom, 4)

                Picker("FPS", selection: $appSettings.frameRate) {
                    ForEach(frameRateOptions, id: \.self) { rate in
                        Text("\(Int(rate))")
                            .tag(rate)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appSettings.frameRate) { oldValue, newValue in
                    AppLogger.settings.info("Frame rate changed: \(Int(newValue)) FPS")
                }

                Text(
                    "Higher frame rates provide smoother previews but use more system resources."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Performance", systemImage: "gauge.medium") }
    }

    /// Experimental features still under development
    private var experimentTab: some View {
        Form {
            // Keyboard shortcuts section
            Section {
                Text("Hotkeys")
                    .font(.headline)
                    .padding(.bottom, 4)

                if appSettings.hotkeyBindings.isEmpty {
                    Text("No hotkeys configured")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(appSettings.hotkeyBindings, id: \.windowTitle) { binding in
                        HStack {
                            Text(binding.windowTitle)
                            Spacer()
                            Text(formatHotkey(binding))
                                .foregroundColor(.secondary)

                            Button(action: {
                                removeHotkeyBinding(binding)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button("Add Hotkey") {
                    AppLogger.settings.debug("Opening hotkey binding sheet")
                    isAddingHotkey = true
                }

                Text(
                    "Hotkeys currently only work while Overview is in focus - this will be improved."
                )
                .font(.caption)
                .foregroundColor(.red)
            }
            .sheet(isPresented: $isAddingHotkey) {
                HotkeyBindingSheet(appSettings: appSettings)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Experimental", systemImage: "flask") }
    }

    // MARK: - Private Methods

    /// Removes a hotkey binding and updates configuration
    /// - Parameter binding: The binding to remove
    private func removeHotkeyBinding(_ binding: HotkeyBinding) {
        AppLogger.settings.debug("Removing hotkey binding for window: '\(binding.windowTitle)'")
        if let index = appSettings.hotkeyBindings.firstIndex(of: binding) {
            appSettings.hotkeyBindings.remove(at: index)
            AppLogger.settings.info("Hotkey binding removed: '\(binding.windowTitle)'")
        }
    }

    /// Resets all settings to default values
    private func resetAllSettings() {
        AppLogger.settings.info("Resetting all settings to defaults")
        appSettings.resetToDefaults()
    }
}

// MARK: - Slider Component

/// Controls opacity through a native slider interface
///
/// Key responsibilities:
/// - Provides smooth, continuous value updates
/// - Maintains precise decimal values through rounding
/// - Validates values within specified range
///
/// Coordinates with:
/// - AppSettings: Updates opacity value through binding
/// - NSSlider: Handles native slider interaction
struct SliderRepresentable: NSViewRepresentable {
    // MARK: - Properties

    /// Current slider value (0.05-1.0)
    @Binding var value: Double

    /// Minimum allowed value (0.05)
    let minValue: Double

    /// Maximum allowed value (1.0)
    let maxValue: Double

    // MARK: - NSViewRepresentable Implementation

    /// Creates and configures the native slider
    ///
    /// Flow:
    /// 1. Creates slider with current value and range
    /// 2. Enables continuous value updates
    /// 3. Connects value change handler
    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(
            value: value,
            minValue: minValue,
            maxValue: maxValue,
            target: context.coordinator,
            action: #selector(Coordinator.valueChanged(_:))
        )
        slider.isContinuous = true
        return slider
    }

    /// Updates slider position when binding changes
    func updateNSView(_ nsView: NSSlider, context: Context) {
        nsView.doubleValue = value
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    // MARK: - Coordinator

    /// Handles slider value changes and binding updates
    ///
    /// Key responsibilities:
    /// - Processes native slider events
    /// - Rounds values for consistent display
    /// - Updates SwiftUI binding
    class Coordinator: NSObject {
        /// Binding to current slider value
        var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        /// Processes slider value changes
        ///
        /// Flow:
        /// 1. Gets raw value from slider
        /// 2. Rounds to 2 decimal places
        /// 3. Updates binding with rounded value
        @objc func valueChanged(_ sender: NSSlider) {
            let rounded = round(sender.doubleValue * 100) / 100
            value.wrappedValue = rounded
        }
    }
}

/// Formats a hotkey binding for display
/// - Parameter binding: The binding to format
/// - Returns: String representation using system key symbols
private func formatHotkey(_ binding: HotkeyBinding) -> String {
    return binding.hotkeyDisplayString
}
