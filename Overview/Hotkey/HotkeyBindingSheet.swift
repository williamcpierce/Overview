/*
 Hotkey/HotkeyBindingSheet.swift
 Overview

 Created by William Pierce on 12/8/24.

 Manages the interface for creating new hotkey bindings, including window selection
 and hotkey recording with validation
*/

import ScreenCaptureKit
import SwiftUI

struct HotkeyBindingSheet: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss

    // MARK: - Dependencies
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var sourceManager: SourceManager
    private let logger = AppLogger.hotkeys

    // MARK: - View State
    @State private var filteredSources: [SCWindow] = []
    @State private var currentShortcut: HotkeyBinding?
    @State private var selectedSource: SCWindow?
    @State private var validationError: String = ""

    var body: some View {
        VStack(spacing: 16) {
            headerView
            sourceSelectionSection
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
            loadFilteredSources()
        }
    }

    // MARK: - View Components

    private var headerView: some View {
        Text("Add Hotkey")
            .font(.headline)
    }

    private var sourceSelectionSection: some View {
        VStack(alignment: .leading) {
            Text("Window:")
            SourceListView(
                selectedSource: $selectedSource,
                sources: filteredSources,
                onSourceSelected: { source in
                    selectedSource = source
                    validateSourceSelection()
                }
            )
            .accessibilityLabel("Window Selection")
        }
    }

    private var shortcutConfigurationSection: some View {
        Group {
            if let source: SCWindow = selectedSource, let title = source.title {
                VStack(alignment: .leading) {
                    Text("Hotkey:")
                    HotkeyRecorder(shortcut: $currentShortcut, sourceTitle: title)
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

    private func loadFilteredSources() {
        Task {
            do {
                filteredSources = try await sourceManager.getFilteredSources()
                logger.info(
                    "Retrieved \(filteredSources.count) source windows for binding selection")
            } catch {
                logger.logError(error, context: "Failed to load source windows for binding")
            }
        }
    }

    private func validateSourceSelection() {
        guard let source: SCWindow = selectedSource,
            let title: String = source.title
        else {
            validationError = ""
            return
        }

        let hasDuplicateTitles: Bool = filteredSources.filter { $0.title == title }.count > 1
        validationError =
            hasDuplicateTitles ? "Warning: Multiple source windows have this title" : ""

        if hasDuplicateTitles {
            logger.warning("Duplicate source window titles detected for '\(title)'")
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
        guard let source: SCWindow = selectedSource,
            source.title != nil,
            currentShortcut != nil,
            validationError.isEmpty
        else { return false }
        return true
    }

    private func saveHotkeyBinding() {
        if let shortcut: HotkeyBinding = currentShortcut {
            appSettings.hotkeyBindings.append(shortcut)
            logger.info(
                "Added new hotkey binding: '\(shortcut.sourceTitle)' - \(shortcut.hotkeyDisplayString)"
            )
            dismiss()
        }
    }
}
