/*
 Shortcut/Settings/ShortcutSettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import KeyboardShortcuts
import SwiftUI

struct ShortcutSettingsTab: View {
    // Dependencies
    @ObservedObject private var shortcutManager: ShortcutManager
    private let logger = AppLogger.settings

    // Private State
    @State private var showingShortcutInfo: Bool = false
    @State private var showingWindowTitlesInfo: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var newWindowTitles: String = ""
    @State private var shortcutToDelete: ShortcutItem?

    // Title Editor State
    @State private var isWindowTitlesEditorVisible: Bool = false
    @State private var shortcutToEdit: ShortcutItem?
    @State private var titlesJSON: String = ""
    @State private var jsonError: String? = nil

    init(shortcutManager: ShortcutManager) {
        self.shortcutManager = shortcutManager
    }

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
                    if shortcutManager.shortcutStorage.shortcuts.isEmpty {
                        List {
                            Text("No shortcuts configured")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        List(shortcutManager.shortcutStorage.shortcuts, id: \.self) { shortcut in
                            HStack {
                                Button(action: {
                                    shortcutToEdit = shortcut
                                    prepareTitlesEditor(for: shortcut)
                                }) {
                                    Image(systemName: "ellipsis.curlybraces")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Edit window titles as JSON")

                                VStack(alignment: .leading) {
                                    ForEach(
                                        Array(shortcut.windowTitles.prefix(2)).indices, id: \.self
                                    ) { index in
                                        Text(shortcut.windowTitles[index])
                                            .lineLimit(1)
                                            .help(shortcut.windowTitles[index])
                                    }

                                    if shortcut.windowTitles.count > 2 {
                                        Text(
                                            "+\(shortcut.windowTitles.count - 2) more"
                                        )
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    }
                                }
                                .frame(width: 160, alignment: .leading)

                                Spacer()

                                KeyboardShortcuts.Recorder("", name: shortcut.shortcutName)
                                    .frame(width: 120)

                                Button(action: {
                                    shortcutToDelete = shortcut
                                    showingDeleteAlert = true
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 8)
                                }
                                .buttonStyle(.plain)
                            }
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
        .alert("Delete Shortcut", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let shortcut = shortcutToDelete {
                    shortcutManager.shortcutStorage.deleteShortcut(id: shortcut.id)
                }
                shortcutToDelete = nil
            }
        } message: {
            if let shortcut = shortcutToDelete {
                let titles = shortcut.windowTitles.joined(separator: ", ")
                Text("Delete shortcut for '\(titles)'? This cannot be undone.")
            } else {
                Text("Select a shortcut to delete")
            }
        }
        .sheet(isPresented: $isWindowTitlesEditorVisible) {
            VStack(spacing: 0) {
                if let error = jsonError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextEditor(text: $titlesJSON)
                        .font(.system(.body, design: .monospaced))
                        .disableAutocorrection(true)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 200)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
            .safeAreaInset(edge: .bottom) {
                VStack {
                    Divider()
                    HStack(spacing: 12) {
                        Spacer()
                        Button("Cancel") {
                            isWindowTitlesEditorVisible = false
                            jsonError = nil
                        }
                        .keyboardShortcut(.cancelAction)

                        Button("Save") {
                            applyTitlesJSON(titlesJSON)
                        }
                        .keyboardShortcut(.defaultAction)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
            }
            .background(.ultraThickMaterial)
            .frame(width: 500)
        }
    }

    // MARK: - Actions

    private func addShortcut() {
        let titles = newWindowTitles.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !titles.isEmpty else { return }

        _ = shortcutManager.shortcutStorage.createShortcut(windowTitles: titles)
        newWindowTitles = ""
    }

    // MARK: - Window Titles JSON Editor

    private func prepareTitlesEditor(for shortcut: ShortcutItem) {
        titlesJSON = windowTitlesToJSON(shortcut.windowTitles)
        isWindowTitlesEditorVisible = true
    }

    private func windowTitlesToJSON(_ titles: [String]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let jsonData = try encoder.encode(titles)
            return String(data: jsonData, encoding: .utf8) ?? "[]"
        } catch {
            logger.logError(error, context: "Failed to convert window titles to JSON")
            return "[]"
        }
    }

    private func applyTitlesJSON(_ jsonString: String) {
        jsonError = nil

        guard let shortcut = shortcutToEdit else {
            jsonError = "No shortcut selected for editing"
            return
        }

        // Replace any curly quotes with straight quotes
        let processedJSON =
            jsonString
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")

        do {
            guard let jsonData = processedJSON.data(using: .utf8) else {
                jsonError = "Invalid text encoding"
                return
            }

            let decoder = JSONDecoder()
            let windowTitles = try decoder.decode([String].self, from: jsonData)

            if !validateWindowTitles(windowTitles) {
                return
            }

            shortcutManager.shortcutStorage.updateShortcut(
                id: shortcut.id, windowTitles: windowTitles)
            isWindowTitlesEditorVisible = false
            logger.info("Successfully updated window titles for shortcut")
        } catch {
            jsonError = "JSON Error: \(error.localizedDescription)"
            logger.logError(error, context: "Failed to parse window titles JSON")
        }
    }

    private func validateWindowTitles(_ titles: [String]) -> Bool {
        if titles.isEmpty {
            jsonError = "Window titles list cannot be empty"
            return false
        }

        if titles.contains(where: { $0.isEmpty }) {
            jsonError = "Window titles cannot be empty strings"
            return false
        }

        return true
    }
}
