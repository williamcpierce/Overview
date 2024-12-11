/*
 HotkeyBindingSheet.swift
 Overview

 Created by William Pierce on 12/8/24.

 Provides the interface for configuring keyboard shortcuts that can trigger window
 focus operations. Part of the hotkey management system that allows users to quickly
 switch between windows using global keyboard shortcuts.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit
import SwiftUI

/// Presents a sheet for creating new hotkey bindings
struct HotkeyBindingSheet: View {
    // MARK: - Properties

    /// Environment-provided dismiss action for closing sheet
    @Environment(\.dismiss) private var dismiss

    /// Global application settings for storing hotkey bindings
    @ObservedObject var appSettings: AppSettings

    /// Currently selected window for binding
    @State private var selectedWindow: SCWindow?

    /// Current keyboard shortcut configuration
    @State private var currentShortcut: HotkeyBinding?

    /// Error message for invalid configurations
    @State private var errorMessage = ""

    /// List of available windows for binding
    @State private var availableWindows: [SCWindow] = []

    // MARK: - View Layout

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Keyboard Shortcut")
                .font(.headline)

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
                    validateSelection()
                }
            }

            if let window = selectedWindow, let title = window.title {
                VStack(alignment: .leading) {
                    Text("Shortcut:")
                    HotkeyRecorder(shortcut: $currentShortcut, windowTitle: title)
                        .frame(height: 24)
                        .accessibilityLabel("Hotkey Recorder")
                        .onChange(of: currentShortcut) { _, _ in
                            validateShortcut()
                        }
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .accessibilityLabel("Cancel Button")

                Button("Add") {
                    if canAddBinding() {
                        addBinding()
                    }
                }
                .accessibilityLabel("Add Button")
                .disabled(!canAddBinding())
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 400)
        .task {
            updateAvailableWindows()
        }
    }

    // MARK: - Private Methods

    /// Updates the list of available windows
    private func updateAvailableWindows() {
        Task {
            availableWindows = await WindowManager.shared.getAvailableWindows()
        }
    }

    /// Validates the current window selection
    private func validateSelection() {
        guard let window = selectedWindow,
              let title = window.title else {
            errorMessage = ""
            return
        }

        // Check for duplicate window titles
        let duplicateTitles = availableWindows.filter { $0.title == title }.count > 1
        if duplicateTitles {
            errorMessage = "Warning: Multiple windows have this title"
        } else {
            errorMessage = ""
        }
    }

    /// Validates the current shortcut configuration
    private func validateShortcut() {
        guard let shortcut = currentShortcut else {
            errorMessage = ""
            return
        }

        // Check for duplicate bindings
        if appSettings.hotkeyBindings.contains(where: { binding in
            binding.keyCode == shortcut.keyCode &&
            binding.modifiers == shortcut.modifiers
        }) {
            errorMessage = "This shortcut is already in use"
            return
        }

        // Ensure at least one modifier
        if shortcut.modifiers.isEmpty {
            errorMessage = "Shortcut must include at least one modifier key"
            return
        }

        errorMessage = ""
    }

    /// Checks if current configuration can be saved
    private func canAddBinding() -> Bool {
        guard let window = selectedWindow,
              window.title != nil,
              currentShortcut != nil,
              errorMessage.isEmpty else {
            return false
        }
        return true
    }

    /// Adds current binding to settings and dismisses sheet
    private func addBinding() {
        if let shortcut = currentShortcut {
            appSettings.hotkeyBindings.append(shortcut)
            dismiss()
        }
    }
}

/// Represents a keyboard shortcut binding to a specific window
///
/// Key responsibilities:
/// - Stores window identification and key combination
/// - Provides consistent string representation of shortcuts
/// - Manages modifier flag compatibility with system APIs
/// - Ensures proper encoding for persistence
///
/// Coordinates with:
/// - HotkeyService: Provides binding data for registration
/// - Carbon Event Manager: Uses compatible key codes
/// - AppSettings: Enables JSON persistence
struct HotkeyBinding: Codable, Equatable, Hashable {
    /// Title of window this binding targets
    let windowTitle: String

    /// Carbon key code for the binding
    /// - Note: Uses Carbon codes for system-wide compatibility
    let keyCode: Int

    /// Raw modifier flag storage
    /// - Note: Private to ensure proper flag handling
    private let modifierFlags: UInt

    /// Computed property for accessing modifier flags
    /// - Note: Ensures compatibility with AppKit/Carbon
    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags)
    }

    /// Creates a new hotkey binding with validated parameters
    ///
    /// Flow:
    /// 1. Stores window identifier
    /// 2. Records key code
    /// 3. Filters valid modifiers
    ///
    /// - Parameters:
    ///   - windowTitle: Title of target window
    ///   - keyCode: Carbon key code for shortcut
    ///   - modifiers: Required modifier keys
    ///
    /// - Warning: Modifiers are filtered to prevent invalid combinations
    init(windowTitle: String, keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        self.windowTitle = windowTitle
        self.keyCode = keyCode
        self.modifierFlags = modifiers.intersection([.command, .option, .control, .shift]).rawValue
    }

    /// Generates human-readable shortcut representation
    ///
    /// Flow:
    /// 1. Builds ordered modifier symbols
    /// 2. Adds key character if known
    /// 3. Falls back to key code display
    ///
    /// - Returns: String using standard system symbols (⌘, ⌥, etc.)
    var hotkeyDisplayString: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if let keyChar = Self.keyCodeToString(keyCode) {
            parts.append(keyChar)
        } else {
            parts.append("Key\(keyCode)")
        }
        return parts.joined(separator: "")
    }

    /// Converts Carbon key codes to displayable characters
    ///
    /// Context: Carbon key codes are used for system-wide hotkey registration
    /// but need translation for user display. This mapping covers the most
    /// common keys users are likely to bind.
    ///
    /// - Parameter keyCode: Carbon key code to convert
    /// - Returns: String representation if known code
    private static func keyCodeToString(_ keyCode: Int) -> String? {
        let keyCodeMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 32: "U", 34: "I", 31: "O", 35: "P",
            37: "L", 38: "J", 39: "K", 40: "'", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "5", 23: "6", 24: "7",
            25: "8", 26: "9", 27: "0",
        ]
        return keyCodeMap[keyCode]
    }
}
