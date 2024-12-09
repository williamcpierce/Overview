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

/// Presents interface for creating and configuring window-specific keyboard shortcuts
///
/// Key responsibilities:
/// - Manages window selection and shortcut recording workflow
/// - Validates shortcut combinations for duplicates and requirements
/// - Coordinates with hotkey system for binding storage
/// - Provides immediate feedback on configuration issues
///
/// Coordinates with:
/// - AppSettings: Persists hotkey configurations
/// - WindowManager: Retrieves available window targets
/// - HotkeyBinding: Creates validated shortcut configurations
/// - HotkeyRecorder: Handles keyboard input capture
struct HotkeyBindingSheet: View {
    // MARK: - Properties
    
    /// Provides sheet dismissal capability
    @Environment(\.dismiss) private var dismiss

    /// Stores and manages hotkey configurations
    @ObservedObject var appSettings: AppSettings

    /// Currently targeted window for shortcut binding
    @State private var selectedWindow: SCWindow?

    /// Active keyboard shortcut configuration
    @State private var currentShortcut: HotkeyBinding?

    /// Current validation failure message
    @State private var errorMessage = ""

    /// Windows available for shortcut binding
    @State private var availableWindows: [SCWindow] = []

    // MARK: - View Layout

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Hotkey")
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
                    Text("Hotkey:")
                    HotkeyRecorder(shortcut: $currentShortcut, windowTitle: title)
                        .frame(height: 24)
                        .accessibilityLabel("Hotkey Recorder")
                        .onChange(of: currentShortcut) { _, _ in
                            validateShortcut()
                        }
                    Text(
                        "Hotkeys must consist of ⌘/⌥/⌃/⇧ plus another standard character."
                    )
                    .font(.caption)
                    .foregroundColor(.primary)
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

    /// Retrieves current list of available windows for binding
    ///
    /// Flow:
    /// 1. Requests filtered window list from manager
    /// 2. Updates view state with results
    /// 3. Handles any window loading failures
    private func updateAvailableWindows() {
        Task {
            AppLogger.windows.debug("Fetching available windows for hotkey binding")
            availableWindows = await WindowManager.shared.getAvailableWindows()
            AppLogger.windows.info("Retrieved \(availableWindows.count) windows for binding")
        }
    }

    /// Validates current window selection for binding conflicts
    ///
    /// Flow:
    /// 1. Checks for valid window selection
    /// 2. Detects duplicate window titles
    /// 3. Updates error state for user feedback
    private func validateSelection() {
        guard let window = selectedWindow,
              let title = window.title else {
            errorMessage = ""
            return
        }

        // Context: Multiple windows with same title could cause focus issues
        let duplicateTitles = availableWindows.filter { $0.title == title }.count > 1
        if duplicateTitles {
            AppLogger.hotkeys.warning("Duplicate window titles detected for '\(title)'")
            errorMessage = "Warning: Multiple windows have this title"
        } else {
            errorMessage = ""
            AppLogger.hotkeys.debug("Window '\(title)' validated for binding")
        }
    }

    /// Validates shortcut configuration for conflicts and requirements
    ///
    /// Flow:
    /// 1. Checks for existing binding conflicts
    /// 2. Validates modifier key requirements
    /// 3. Updates error state with validation results
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
            AppLogger.hotkeys.warning("Duplicate shortcut detected: \(shortcut.hotkeyDisplayString)")
            errorMessage = "This shortcut is already in use"
            return
        }

        // Context: Modifier required to prevent accidental triggers
        if shortcut.modifiers.isEmpty {
            AppLogger.hotkeys.warning("Shortcut missing required modifier key")
            errorMessage = "Shortcut must include at least one modifier key"
            return
        }

        errorMessage = ""
        AppLogger.hotkeys.debug("Shortcut validated: \(shortcut.hotkeyDisplayString)")
    }

    /// Determines if current configuration is valid for saving
    ///
    /// Flow:
    /// 1. Validates window selection exists
    /// 2. Confirms shortcut is configured
    /// 3. Checks for validation errors
    private func canAddBinding() -> Bool {
        guard let window = selectedWindow,
              window.title != nil,
              currentShortcut != nil,
              errorMessage.isEmpty else {
            return false
        }
        return true
    }

    /// Saves current binding configuration and closes sheet
    ///
    /// Flow:
    /// 1. Validates current shortcut
    /// 2. Adds to global configuration
    /// 3. Triggers sheet dismissal
    private func addBinding() {
        if let shortcut = currentShortcut {
            AppLogger.hotkeys.info("Adding new hotkey binding: '\(shortcut.windowTitle)' -> \(shortcut.hotkeyDisplayString)")
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
    // MARK: - Properties

    /// Title of window this binding targets
    let windowTitle: String

    /// Carbon key code for the binding
    /// - Note: Uses Carbon codes for system-wide compatibility
    let keyCode: Int

    /// Raw modifier flag storage
    /// - Note: Private to ensure proper flag handling
    private let modifierFlags: UInt

    // MARK: - Computed Properties

    /// Computed property for accessing modifier flags
    /// - Note: Ensures compatibility with AppKit/Carbon
    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags)
    }

    // MARK: - Initialization

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
        // Context: Only allow standard modifier keys for compatibility
        self.modifierFlags = modifiers.intersection([.command, .option, .control, .shift]).rawValue
        
        AppLogger.hotkeys.debug("Created binding for '\(windowTitle)' with key code \(keyCode)")
    }

    // MARK: - Public Methods

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

    // MARK: - Private Methods

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
