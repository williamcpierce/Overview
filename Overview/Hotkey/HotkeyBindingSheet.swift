/*
 HotkeyBindingSheet.swift
 Overview

 Created by William Pierce on 12/8/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit
import SwiftUI

struct HotkeyBindingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appSettings: AppSettings
    @State private var selectedWindow: SCWindow?
    @State private var currentShortcut: HotkeyBinding?
    @State private var errorMessage = ""
    @State private var availableWindows: [SCWindow] = []

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

    private func updateAvailableWindows() {
        Task {
            availableWindows = await WindowManager.shared.getAvailableWindows()
        }
    }

    private func validateSelection() {
        guard let window = selectedWindow,
            let title = window.title
        else {
            errorMessage = ""
            return
        }

        let duplicateTitles = availableWindows.filter { $0.title == title }.count > 1
        if duplicateTitles {
            errorMessage = "Warning: Multiple windows have this title"
        } else {
            errorMessage = ""
        }
    }

    private func validateShortcut() {
        guard let shortcut = currentShortcut else {
            errorMessage = ""
            return
        }

        if appSettings.hotkeyBindings.contains(where: { binding in
            binding.keyCode == shortcut.keyCode && binding.modifiers == shortcut.modifiers
        }) {
            errorMessage = "This shortcut is already in use"
            return
        }

        if shortcut.modifiers.isEmpty {
            errorMessage = "Shortcut must include at least one modifier key"
            return
        }

        errorMessage = ""
    }

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

    private func addBinding() {
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
