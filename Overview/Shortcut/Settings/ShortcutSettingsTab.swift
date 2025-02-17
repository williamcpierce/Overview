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

                if shortcutStorage.shortcuts.isEmpty {
                    Text("No shortcuts configured")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(shortcutStorage.shortcuts) { shortcut in
                            ShortcutRow(shortcut: shortcut)
                        }
                        .onDelete { indices in
                            indices.forEach { index in
                                shortcutStorage.removeShortcut(shortcutStorage.shortcuts[index])
                            }
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

    private func addShortcut() {
        guard !newWindowTitle.isEmpty else { return }
        shortcutStorage.addShortcut(newWindowTitle)
        newWindowTitle = ""
    }
}

struct ShortcutRow: View {
    let shortcut: ShortcutItem

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(shortcut.windowTitle)
                    .lineLimit(1)
                KeyboardShortcuts.Recorder("", name: shortcut.shortcutName)
            }
        }
    }
}
