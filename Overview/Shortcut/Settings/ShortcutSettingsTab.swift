/*
 Shortcut/Settings/ShortcutSettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import KeyboardShortcuts
import SwiftUI

struct ShortcutSettingsTab: View {
    // Dependencies
    @StateObject private var shortcutStorage = ShortcutStorage.shared
    private let logger = AppLogger.settings

    // Private State
    @State private var showingShortcutInfo: Bool = false
    @State private var newWindowTitle: String = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Window Activation")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .shortcutActivation,
                        isPresented: $showingShortcutInfo
                    )
                }
                .padding(.bottom, 4)

                VStack {
                    if shortcutStorage.shortcuts.isEmpty {
                        List {
                            Text("No shortcuts configured")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        List(shortcutStorage.shortcuts, id: \.self) { shortcut in
                            ShortcutRow(shortcut: shortcut)
                        }
                    }
                }

                HStack {
                    TextField("Window Title", text: $newWindowTitle)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                    Button("Add") {
                        addShortcut()
                    }
                    .disabled(newWindowTitle.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions

    private func addShortcut() {
        guard !newWindowTitle.isEmpty else { return }
        shortcutStorage.addShortcut(newWindowTitle)
        newWindowTitle = ""
    }
}

struct ShortcutRow: View {
    // Dependencies
    @StateObject private var shortcutStorage = ShortcutStorage.shared
    let shortcut: ShortcutItem

    var body: some View {
        HStack {
            Text(shortcut.windowTitle)
                .frame(width: 140, alignment: .leading)
                .lineLimit(1)
                .help(shortcut.windowTitle)
            Spacer()
            KeyboardShortcuts.Recorder("", name: shortcut.shortcutName)
                .frame(width: 120)
            Button(action: { shortcutStorage.removeShortcut(shortcut) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            .buttonStyle(.plain)
        }
    }
}
