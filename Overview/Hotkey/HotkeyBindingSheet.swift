/*
 HotkeyBindingSheet.swift
 Overview

 Created by William Pierce on 12/8/24.

 Provides the interface for configuring keyboard shortcuts that can trigger window
 focus operations. Part of the hotkey management system that allows users to quickly
 switch between windows using global keyboard shortcuts.
*/

import AppKit
import Carbon
import CoreGraphics
import ScreenCaptureKit
import SwiftUI

struct HotkeyBindingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appSettings: AppSettings

    @State private var selectedWindow: SCWindow?
    @State private var currentShortcut: HotkeyBinding?
    @State private var validationError = ""
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
            availableWindows = await WindowManager.shared.getAvailableWindows()
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

struct HotkeyBinding: Codable, Equatable, Hashable {
    let windowTitle: String
    let keyCode: Int
    private let modifierFlags: UInt

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags)
    }

    init(windowTitle: String, keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        self.windowTitle = windowTitle
        self.keyCode = keyCode
        self.modifierFlags = modifiers.intersection([.command, .option, .control, .shift]).rawValue
    }

    var hotkeyDisplayString: String {
        var modifierSymbols = [String]()
        if modifiers.contains(.command) { modifierSymbols.append("⌘") }
        if modifiers.contains(.option) { modifierSymbols.append("⌥") }
        if modifiers.contains(.control) { modifierSymbols.append("⌃") }
        if modifiers.contains(.shift) { modifierSymbols.append("⇧") }

        let keySymbol = Self.translateKeyCodeToSymbol(keyCode) ?? "Key\(keyCode)"
        modifierSymbols.append(keySymbol)

        return modifierSymbols.joined()
    }

    /// Translates Carbon key codes to human-readable symbols using the current keyboard layout
    private static func translateKeyCodeToSymbol(_ keyCode: Int) -> String? {
        let specialKeys: [Int: String] = [
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]

        if let specialKey = specialKeys[keyCode] {
            return specialKey
        }

        guard let currentKeyboard = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutData = TISGetInputSourceProperty(
                currentKeyboard, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let keyboardLayout = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        var chars = [UniChar](repeating: 0, count: 4)
        var stringLength = 0
        var deadKeyState: UInt32 = 0

        let status = keyboardLayout.withUnsafeBytes { buffer in
            guard let layoutPtr = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self)
            else { return errSecInvalidKeychain }

            return UCKeyTranslate(
                layoutPtr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &stringLength,
                &chars
            )
        }

        guard status == noErr else { return nil }
        return String(utf16CodeUnits: chars, count: stringLength).uppercased()
    }
}
