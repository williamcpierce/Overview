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
    @State private var showingWindowTitlesInfo: Bool = false
    @State private var newWindowTitles: String = ""

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
                    TextField("Window title(s)", text: $newWindowTitles)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                    Spacer()
                    InfoPopover(
                        content: .shortcutWindowTitles,
                        isPresented: $showingWindowTitlesInfo
                    )
                    Button("Add") {
                        addShortcut()
                    }
                    .disabled(newWindowTitles.isEmpty)

                }
            }
        }
        .formStyle(.grouped)
        .frame(width:384)
    }

    // MARK: - Actions

    private func addShortcut() {
        let titles = newWindowTitles.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !titles.isEmpty else { return }

        shortcutStorage.addShortcut(windowTitles: titles)
        newWindowTitles = ""
    }
}

struct ShortcutRow: View {
    // Dependencies
    @StateObject private var shortcutStorage = ShortcutStorage.shared
    let shortcut: ShortcutItem

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                ForEach(shortcut.windowTitles, id: \.self) { title in
                    Text(title)
                        .lineLimit(1)
                        .help(title)
                }
            }
            .frame(width: 180, alignment: .leading)

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
