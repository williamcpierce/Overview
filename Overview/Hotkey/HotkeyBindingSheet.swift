/*
 Hotkey/HotkeyBindingSheet.swift
 Overview

 Created by William Pierce on 12/8/24.
*/

import ScreenCaptureKit
import SwiftUI

/// Manages the interface for creating new hotkey bindings, including window selection
/// and hotkey recording with validation
struct HotkeyBindingSheet: View {
    // MARK: - Dependencies

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var windowManager: WindowManager
    private let logger = AppLogger.hotkeys

    // MARK: - View State

    @State private var filteredWindows: [SCWindow] = []
    @State private var currentShortcut: HotkeyBinding?
    @State private var selectedWindow: SCWindow?
    @State private var validationError: String = ""

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
            loadFilteredWindows()
        }
    }

    // MARK: - View Components

    private var headerView: some View {
        Text("Add Hotkey")
            .font(.headline)
    }

    private var windowSelectionSection: some View {
        VStack(alignment: .leading) {
            Text("Window:")
            Picker("", selection: $selectedWindow) {
                Text("Select a window").tag(Optional<SCWindow>.none)
                ForEach(filteredWindows, id: \.windowID) { window in
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
            if let window: SCWindow = selectedWindow, let title = window.title {
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

    // MARK: - Private Methods

    private func loadFilteredWindows() {
        Task {
            do {
                filteredWindows = try await windowManager.getFilteredWindows()
                logger.info("Retrieved \(filteredWindows.count) windows for binding selection")
            } catch {
                logger.error("Failed to load windows for binding: \(error.localizedDescription)")
            }
        }
    }

    private func validateWindowSelection() {
        guard let window: SCWindow = selectedWindow,
            let title: String = window.title
        else {
            validationError = ""
            return
        }

        let hasDuplicateTitles: Bool = filteredWindows.filter { $0.title == title }.count > 1
        validationError = hasDuplicateTitles ? "Warning: Multiple windows have this title" : ""

        if hasDuplicateTitles {
            logger.warning("Duplicate window titles detected for '\(title)'")
        }
    }

    private func validateShortcutConfiguration() {
        guard let shortcut: HotkeyBinding = currentShortcut else {
            validationError = ""
            return
        }

        if hasConflictingShortcut(shortcut) {
            validationError = "This shortcut is already in use"
            logger.warning("Conflicting shortcut detected: \(shortcut.hotkeyDisplayString)")
            return
        }

        if shortcut.modifiers.isEmpty {
            validationError = "Shortcut must include at least one modifier key"
            logger.warning("Invalid shortcut: no modifier keys specified")
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
        guard let window: SCWindow = selectedWindow,
            window.title != nil,
            currentShortcut != nil,
            validationError.isEmpty
        else { return false }
        return true
    }

    private func saveHotkeyBinding() {
        if let shortcut: HotkeyBinding = currentShortcut {
            appSettings.hotkeyBindings.append(shortcut)
            logger.info(
                "Added new hotkey binding: '\(shortcut.windowTitle)' - \(shortcut.hotkeyDisplayString)"
            )
            dismiss()
        }
    }
}
