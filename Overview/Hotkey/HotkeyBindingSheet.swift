/*
 Hotkey/HotkeyBindingSheet.swift
 Overview

 Created by William Pierce on 12/8/24.

 Provides the interface for configuring keyboard shortcuts that can trigger window
 focus operations. Part of the hotkey management system that allows users to quickly
 switch between windows using global keyboard shortcuts.
*/

import ScreenCaptureKit
import SwiftUI

struct HotkeyBindingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var windowManager: WindowManager

    @State private var selectedWindow: SCWindow?
    @State private var currentShortcut: HotkeyBinding?
    @State private var validationError: String = ""
    @State private var availableWindows: [SCWindow] = []

    var body: some View {
        VStack(spacing: 16) {
            headerView
            windowSelectionSection
            shortcutConfigurationSection
            if !validationError.isEmpty {
                Text(validationError)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            actionButtons
        }
        .padding()
        .frame(width: 400)
        .task {
            loadAvailableWindows()
        }
    }

    private var headerView: some View {
        Text("Add Hotkey")
            .font(.headline)
    }

    private var windowSelectionSection: some View {
        VStack(alignment: .leading) {
            Text("Window:")
            Picker("", selection: $selectedWindow) {
                Text("Select a window").tag(Optional<SCWindow>.none)
                ForEach(availableWindows, id: \.windowID) { window in
                    Text(window.title ?? "Untitled").tag(Optional(window))
                }
            }
            .accessibilityLabel("Window Selection")
            .onChange(of: selectedWindow) { _, _ in
                validateWindowSelection()
            }
        }
    }

    private var shortcutConfigurationSection: some View {
        Group {
            if let window = selectedWindow, let title = window.title {
                VStack(alignment: .leading) {
                    Text("Hotkey:")
                    HotkeyRecorder(shortcut: $currentShortcut, windowTitle: title)
                        .frame(height: 24)
                        .accessibilityLabel("Hotkey Recorder")
                        .onChange(of: currentShortcut) { _, _ in
                            validateShortcutConfiguration()
                        }
                    Text("Hotkeys must consist of ⌘/⌥/⌃/⇧ plus another standard character.")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .accessibilityLabel("Cancel Button")

            Button("Add") {
                if isValidConfiguration() {
                    saveHotkeyBinding()
                }
            }
            .accessibilityLabel("Add Button")
            .disabled(!isValidConfiguration())
        }
        .padding(.top)
    }

    private func loadAvailableWindows() {
        Task {
            availableWindows = await windowManager.getFilteredWindows()
            AppLogger.windows.info("Retrieved \(availableWindows.count) windows for binding")
        }
    }

    private func validateWindowSelection() {
        guard let window = selectedWindow,
            let title = window.title
        else {
            validationError = ""
            return
        }

        let hasDuplicateTitles = availableWindows.filter { $0.title == title }.count > 1
        validationError = hasDuplicateTitles ? "Warning: Multiple windows have this title" : ""
    }

    private func validateShortcutConfiguration() {
        guard let shortcut = currentShortcut else {
            validationError = ""
            return
        }

        if hasConflictingShortcut(shortcut) {
            validationError = "This shortcut is already in use"
            return
        }

        if shortcut.modifiers.isEmpty {
            validationError = "Shortcut must include at least one modifier key"
            return
        }

        validationError = ""
    }

    private func hasConflictingShortcut(_ shortcut: HotkeyBinding) -> Bool {
        appSettings.hotkeyBindings.contains { binding in
            binding.keyCode == shortcut.keyCode && binding.modifiers == shortcut.modifiers
        }
    }

    private func isValidConfiguration() -> Bool {
        guard let window = selectedWindow,
            window.title != nil,
            currentShortcut != nil,
            validationError.isEmpty
        else { return false }
        return true
    }

    private func saveHotkeyBinding() {
        if let shortcut = currentShortcut {
            appSettings.hotkeyBindings.append(shortcut)
            dismiss()
        }
    }
}
