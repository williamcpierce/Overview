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
    @State private var newAppFilterName: String = ""
    private let logger = AppLogger.settings

    var body: some View {
        TabView {
            generalTab
            windowTab
            performanceTab
            hotkeyTab
            filterTab
        }
        .frame(width: 360)
        .background(.ultraThickMaterial)
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
        .frame(height: 430)
    }

    private var windowTab: some View {
        Form {
            windowOpacityConfiguration
            defaultWindowSizeConfiguration
            windowBehaviorConfiguration
        }
        .formStyle(.grouped)
        .tabItem { Label("Previews", systemImage: "macwindow") }
        .frame(height: 540)
    }

    private var performanceTab: some View {
        Form {
            frameRateConfiguration
        }
        .formStyle(.grouped)
        .tabItem { Label("Performance", systemImage: "gauge.medium") }
        .frame(height: 170)
    }

    private var hotkeyTab: some View {
        Form {
            hotkeyConfiguration
        }
        .formStyle(.grouped)
        .tabItem { Label("Hotkeys", systemImage: "command.square.fill") }
        .frame(height: 430)
    }

    private var filterTab: some View {
        Form {
            filterConfiguration
        }
        .formStyle(.grouped)
        .tabItem { Label("Filter", systemImage: "line.3.horizontal.decrease.circle.fill") }
        .frame(height: 430)
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
        .padding(.bottom, 10)
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
            closeOnCaptureStop
            hideInactiveApplicationsToggle
            hideActiveWindowToggle
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

    // MARK: - Filter Tab Components

    private var filterConfiguration: some View {
        Section {
            sectionHeader("Selection Dropdown Filter")
            appFilterMode
            appFilterList
            addAppFilterButton
        }
    }

    private var appFilterList: some View {
        Group {
            if appSettings.appFilterNames.isEmpty {
                Text("No applications configured")
                    .foregroundColor(.secondary)
            } else {
                ForEach(appSettings.appFilterNames, id: \.self) { appName in
                    appFilterRow(appName)
                }
            }
        }
    }

    private func appFilterRow(_ appName: String) -> some View {
        HStack {
            Text(appName)
            Spacer()
            removeAppButton(appName)
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

    private var closeOnCaptureStop: some View {
        Toggle("Close preview with source window", isOn: $appSettings.closeOnCaptureStop)
            .onChange(of: appSettings.closeOnCaptureStop) { _, newValue in
                logger.info("Close on capture stop changed: \(newValue)")
            }
    }

    private var hideInactiveApplicationsToggle: some View {
        Toggle(
            "Hide previews for inactive applications", isOn: $appSettings.hideInactiveApplications
        )
        .onChange(of: appSettings.hideInactiveApplications) { _, newValue in
            logger.info("Hide inactive applications changed: \(newValue)")
        }
    }

    private var hideActiveWindowToggle: some View {
        Toggle("Hide preview for active window", isOn: $appSettings.hideActiveWindow)
            .onChange(of: appSettings.hideActiveWindow) { _, newValue in
                logger.info("Hide active windows changed: \(newValue)")
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

    private var appFilterMode: some View {
        Picker("Filter Mode", selection: $appSettings.isFilterBlocklist) {
            Text("Blocklist").tag(true)
            Text("Allowlist").tag(false)
        }
        .pickerStyle(.segmented)
    }

    private var addAppFilterButton: some View {
        HStack {
            TextField("App Name", text: $newAppFilterName)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
            Button("Add") { addAppFilterName() }
                .disabled(newAppFilterName.isEmpty)
        }
    }

    private func removeAppButton(_ appName: String) -> some View {
        Button(action: {
            removeAppFilterName(appName)
        }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func removeHotkeyBinding(_ binding: HotkeyBinding) {
        if let index: Int = appSettings.hotkeyBindings.firstIndex(of: binding) {
            appSettings.hotkeyBindings.remove(at: index)
            logger.info("Hotkey binding removed: '\(binding.windowTitle)'")
        }
    }

    private func addAppFilterName() {
        guard !newAppFilterName.isEmpty else { return }
        appSettings.appFilterNames.append(newAppFilterName)
        newAppFilterName = ""
    }

    private func removeAppFilterName(_ appName: String) {
        if let index: Int = appSettings.appFilterNames.firstIndex(of: appName) {
            appSettings.appFilterNames.remove(at: index)
            logger.info("App filter removed: '\(appName)'")
        }
    }
}

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
        slider.isContinuous = false
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
