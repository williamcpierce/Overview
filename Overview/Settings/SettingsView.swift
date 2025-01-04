/*
 Settings/SettingsView.swift
 Overview

 Created by William Pierce on 10/13/24.
*/

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var windowManager: WindowManager
    @State private var isAddingHotkey: Bool = false
    @State private var showingResetAlert: Bool = false
    private let logger = AppLogger.settings

    var body: some View {
        TabView {
            generalTab
            windowTab
            performanceTab
            hotkeyTab
        }
        .frame(width: 360, height: 430)
    }

    private var generalTab: some View {
        Form {
            focusBorderConfiguration
            titleOverlayConfiguration
        }
        .formStyle(.grouped)
        .tabItem { Label("General", systemImage: "gear") }
        .safeAreaInset(edge: .bottom) {
            resetSettingsButton
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            resetSettingsAlert
        }
    }

    private var windowTab: some View {
        Form {
            windowOpacityConfiguration
            defaultWindowSizeConfiguration
            windowBehaviorConfiguration
        }
        .formStyle(.grouped)
        .tabItem { Label("Previews", systemImage: "macwindow") }
    }

    private var performanceTab: some View {
        Form {
            frameRateConfiguration
        }
        .formStyle(.grouped)
        .tabItem { Label("Performance", systemImage: "gauge.medium") }
    }

    private var hotkeyTab: some View {
        Form {
            hotkeyConfiguration
        }
        .formStyle(.grouped)
        .tabItem { Label("Hotkeys", systemImage: "command.square.fill") }
    }

    // MARK: - General Tab Components

    private var focusBorderConfiguration: some View {
        Section {
            sectionHeader("Border Overlay")
            Toggle("Show focused window border", isOn: $appSettings.showFocusedBorder)
                .onChange(of: appSettings.showFocusedBorder) { _, newValue in
                    logger.info("Window border visibility changed: \(newValue)")
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
    }

    private var titleOverlayConfiguration: some View {
        Section {
            sectionHeader("Title Overlay")
            Toggle("Show window title", isOn: $appSettings.showWindowTitle)
                .onChange(of: appSettings.showWindowTitle) { _, newValue in
                    logger.info("Window title visibility changed: \(newValue)")
                }

            if appSettings.showWindowTitle {
                HStack {
                    Text("Font size")
                    Spacer()
                    TextField(
                        "", value: $appSettings.titleFontSize,
                        formatter: NumberFormatter()
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
                        OpacitySlider(value: $appSettings.titleBackgroundOpacity)
                        Text("\(Int(appSettings.titleBackgroundOpacity * 100))%")
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }
                }
            }
        }
    }

    private var resetSettingsButton: some View {
        Button("Reset All Settings") {
            showingResetAlert = true
        }
        .padding(.bottom, 8)
    }

    private var resetSettingsAlert: some View {
        Group {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                appSettings.resetToDefaults()
            }
        }
    }

    // MARK: - Window Tab Components

    private var windowOpacityConfiguration: some View {
        Section {
            sectionHeader("Opacity")
            HStack(spacing: 8) {
                OpacitySlider(value: $appSettings.windowOpacity)
                Text("\(Int(appSettings.windowOpacity * 100))%")
                    .foregroundColor(.secondary)
                    .frame(width: 40)
            }
        }
    }

    private var defaultWindowSizeConfiguration: some View {
        Section {
            sectionHeader("Default Size")
            dimensionField("Width", binding: $appSettings.defaultWindowWidth)
            dimensionField("Height", binding: $appSettings.defaultWindowHeight)
        }
    }

    private var windowBehaviorConfiguration: some View {
        Section {
            sectionHeader("Behavior")
            missionControlToggle
            hideInactiveWindowsToggle
            editModeAlignmentToggle
            alignmentHelpText
        }
    }

    // MARK: - Performance Tab Components

    private var frameRateConfiguration: some View {
        Section {
            sectionHeader("Frame Rate")
            Picker("FPS", selection: $appSettings.frameRate) {
                ForEach(appSettings.availableFrameRates, id: \.self) { rate in
                    Text("\(Int(rate))").tag(rate)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: appSettings.frameRate) { _, newValue in
                logger.info("Frame rate changed: \(Int(newValue)) FPS")
            }
            Text("Higher frame rates provide smoother previews but use more system resources.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Hotkey Tab Components

    private var hotkeyConfiguration: some View {
        Section {
            sectionHeader("Hotkeys")
            hotkeyList
            addHotkeyButton
        }
        .sheet(isPresented: $isAddingHotkey) {
            HotkeyBindingSheet(
                appSettings: appSettings,
                windowManager: windowManager
            )
        }
    }

    private var hotkeyList: some View {
        Group {
            if appSettings.hotkeyBindings.isEmpty {
                Text("No hotkeys configured")
                    .foregroundColor(.secondary)
            } else {
                ForEach(appSettings.hotkeyBindings, id: \.windowTitle) { binding in
                    hotkeyRow(binding)
                }
            }
        }
    }

    private func hotkeyRow(_ binding: HotkeyBinding) -> some View {
        HStack {
            Text(binding.windowTitle)
            Spacer()
            Text(binding.hotkeyDisplayString)
                .foregroundColor(.secondary)
            removeHotkeyButton(binding)
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .padding(.bottom, 4)
    }

    private func dimensionField(_ label: String, binding: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: binding, formatter: NumberFormatter())
                .frame(width: 120)
                .textFieldStyle(.roundedBorder)
                .onChange(of: binding.wrappedValue) { _, newValue in
                    logger.info(
                        "Default window \(label.lowercased()) changed: \(newValue)px")
                }
            Text("px")
                .foregroundColor(.secondary)
        }
    }

    private var missionControlToggle: some View {
        Toggle("Show in Mission Control", isOn: $appSettings.managedByMissionControl)
            .onChange(of: appSettings.managedByMissionControl) { _, newValue in
                logger.info("Mission Control integration changed: \(newValue)")
            }
    }
    
    private var hideInactiveWindowsToggle: some View {
        Toggle("Hide previews for inactive applications", isOn: $appSettings.hideInactiveWindows)
            .onChange(of: appSettings.hideInactiveWindows) { _, newValue in
                logger.info("Hide inactive windows changed: \(newValue)")
            }
    }

    private var editModeAlignmentToggle: some View {
        Toggle("Enable alignment help in edit mode", isOn: $appSettings.enableEditModeAlignment)
            .onChange(of: appSettings.enableEditModeAlignment) { _, newValue in
                logger.info("Edit mode alignment changed: \(newValue)")
            }
    }

    private var alignmentHelpText: some View {
        Text(
            "Alignment help will cause preview windows to show behind some other windows until edit mode is turned off."
        )
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private var addHotkeyButton: some View {
        Button("Add Hotkey") {
            logger.debug("Opening hotkey binding sheet")
            isAddingHotkey = true
        }
    }

    private func removeHotkeyButton(_ binding: HotkeyBinding) -> some View {
        Button(action: {
            removeHotkeyBinding(binding)
        }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func removeHotkeyBinding(_ binding: HotkeyBinding) {
        if let index: Int = appSettings.hotkeyBindings.firstIndex(of: binding) {
            appSettings.hotkeyBindings.remove(at: index)
            logger.info("Hotkey binding removed: '\(binding.windowTitle)'")
        }
    }
}

/// Provides a native slider for opacity control with precise decimal value handling
struct OpacitySlider: NSViewRepresentable {
    @Binding var value: Double

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(
            value: value,
            minValue: 0.05,
            maxValue: 1.0,
            target: context.coordinator,
            action: #selector(Coordinator.valueChanged(_:))
        )
        slider.isContinuous = true
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        nsView.doubleValue = value
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    class Coordinator: NSObject {
        var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc func valueChanged(_ sender: NSSlider) {
            value.wrappedValue = round(sender.doubleValue * 100) / 100
        }
    }
}
