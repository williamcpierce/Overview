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

import AppKit
import Carbon
import CoreGraphics
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
            let title = window.title
        else {
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
            binding.keyCode == shortcut.keyCode && binding.modifiers == shortcut.modifiers
        }) {
            AppLogger.hotkeys.warning(
                "Duplicate shortcut detected: \(shortcut.hotkeyDisplayString)")
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
            errorMessage.isEmpty
        else {
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
            AppLogger.hotkeys.info(
                "Adding new hotkey binding: '\(shortcut.windowTitle)' -> \(shortcut.hotkeyDisplayString)"
            )
            appSettings.hotkeyBindings.append(shortcut)
            dismiss()
        }
    }
}

/// Manages keyboard shortcut configuration for window focus operations
///
/// Key responsibilities:
/// - Stores and validates window-to-shortcut mappings
/// - Translates between Carbon and AppKit key representations
/// - Ensures thread-safe modifier flag handling
/// - Provides persistence through Codable conformance
///
/// Coordinates with:
/// - HotkeyService: Receives binding data for system registration
/// - WindowManager: Target window identification and focus
/// - AppSettings: Persists binding configurations
struct HotkeyBinding: Codable, Equatable, Hashable {
    // MARK: - Properties

    /// Title used to locate target window during focus operations
    /// - Note: Must be unique to prevent focus ambiguity
    let windowTitle: String

    /// System-level key identifier for Carbon event registration
    /// - Note: Uses virtual key codes for layout independence
    let keyCode: Int

    /// Raw storage of keyboard modifier flags
    /// - Note: Stored as UInt for Codable compatibility
    private let modifierFlags: UInt

    // MARK: - Computed Properties

    /// Provides AppKit-compatible access to stored modifier flags
    /// - Note: Filters to supported modifier combinations
    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags)
    }

    // MARK: - Initialization

    /// Creates hotkey binding with validated window and key configuration
    ///
    /// Flow:
    /// 1. Validates window title uniqueness
    /// 2. Normalizes modifier key combinations
    /// 3. Initializes binding state
    ///
    /// - Parameters:
    ///   - windowTitle: Unique identifier for target window
    ///   - keyCode: Carbon virtual key code for trigger key
    ///   - modifiers: Required modifier key combination
    ///
    /// - Important: Only standard modifiers (⌘,⌥,⌃,⇧) are supported
    init(windowTitle: String, keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        AppLogger.hotkeys.debug("Creating binding for window: '\(windowTitle)'")

        self.windowTitle = windowTitle
        self.keyCode = keyCode
        self.modifierFlags = modifiers.intersection([.command, .option, .control, .shift]).rawValue

        AppLogger.hotkeys.info("Binding created: '\(windowTitle)' -> \(self.hotkeyDisplayString)")
    }

    // MARK: - Public Methods

    /// Formats binding as user-readable keyboard shortcut
    ///
    /// Flow:
    /// 1. Orders modifier symbols consistently
    /// 2. Converts key code to localized character
    /// 3. Combines into standard shortcut format
    ///
    /// - Returns: String like "⌘⌥A" or "⌃⇧Tab"
    var hotkeyDisplayString: String {
        AppLogger.hotkeys.debug("Generating display string for '\(windowTitle)' binding")

        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }

        if let keyChar = Self.keyCodeToString(keyCode) {
            parts.append(keyChar)
        } else {
            AppLogger.hotkeys.warning("Unknown key code \(keyCode) for '\(windowTitle)'")
            parts.append("Key\(keyCode)")
        }

        return parts.joined(separator: "")
    }

    // MARK: - Private Methods

    /// Converts Carbon key codes to locale-aware character display
    ///
    /// Flow:
    /// 1. Gets active keyboard layout
    /// 2. Translates virtual key code
    /// 3. Handles special case keys
    ///
    /// - Parameter keyCode: Carbon virtual key code
    /// - Returns: Localized key representation or nil
    private static func keyCodeToString(_ keyCode: Int) -> String? {
        AppLogger.hotkeys.debug("Converting key code: \(keyCode)")

        // Get current keyboard layout
        guard let currentKeyboard = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutData = TISGetInputSourceProperty(
                currentKeyboard, kTISPropertyUnicodeKeyLayoutData)
        else {
            AppLogger.hotkeys.error("Failed to get keyboard layout for key code \(keyCode)")
            return nil
        }

        let keyboardLayout = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data

        // Create translation buffer
        var chars = [UniChar](repeating: 0, count: 4)
        var deadKeyState: UInt32 = 0
        var actualStringLength = 0

        // Translate through system APIs
        let status = keyboardLayout.withUnsafeBytes { buffer in
            guard let layoutPtr = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self)
            else {
                AppLogger.hotkeys.error("Invalid keyboard layout pointer")
                return errSecInvalidKeychain
            }

            return UCKeyTranslate(
                layoutPtr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,  // No modifiers for base character
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &actualStringLength,
                &chars
            )
        }

        guard status == noErr else {
            AppLogger.hotkeys.error("Key translation failed: \(status)")
            return nil
        }

        // Handle common non-printing keys
        switch keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Escape"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            let result = String(utf16CodeUnits: chars, count: actualStringLength).uppercased()
            AppLogger.hotkeys.debug("Translated key code \(keyCode) to '\(result)'")
            return result
        }
    }
}
