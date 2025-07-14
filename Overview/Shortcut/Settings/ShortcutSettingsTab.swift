/*
 Shortcut/Settings/ShortcutSettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import KeyboardShortcuts
import ScreenCaptureKit
import SwiftUI

struct ShortcutSettingsTab: View {
    // Dependencies
    @ObservedObject private var shortcutManager: ShortcutManager
    @ObservedObject private var sourceManager: SourceManager
    private let logger = AppLogger.settings

    // Private State
    @State private var showingShortcutInfo: Bool = false
    @State private var showingWindowTitlesInfo: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var newWindowTitles: String = ""
    @State private var shortcutToDelete: Shortcut?

    // Title Editor State
    @State private var isWindowTitlesEditorVisible: Bool = false
    @State private var shortcutToEdit: Shortcut?
    @State private var titlesJSON: String = ""
    @State private var jsonError: String? = nil

    @State private var availableSources: [SCWindow] = []
    @State private var sourceListVersion: UUID = UUID()
    
    @State private var enabledStates: [UUID: Bool] = [:]

    init(shortcutManager: ShortcutManager, sourceManager: SourceManager) {
        self.shortcutManager = shortcutManager
        self.sourceManager = sourceManager
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

                                Spacer()

                                KeyboardShortcuts.Recorder("", name: shortcut.shortcutName)
                                    .frame(width: 120)

                                if let isEnabled = enabledStates[shortcut.id] {
                                    Toggle("", isOn: Binding(
                                        get: { isEnabled },
                                        set: { newValue in
                                            enabledStates[shortcut.id] = newValue
                                        }
                                    ))
                                    .onChange(of: enabledStates[shortcut.id]) { newValue in
                                        if let newValue = newValue {
                                            shortcutManager.shortcutStorage.updateShortcut(
                                                id: shortcut.id, isEnabled: newValue
                                            )
                                        }
                                    }
                                    .toggleStyle(.switch)
                                    .scaleEffect(0.7)
                                    .labelsHidden()
                                    .padding(.leading, 8)
                                }

                                Button(action: {
                                    shortcutToDelete = shortcut
                                    showingDeleteAlert = true
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                VStack {
                    HStack {
                        Text("Window Title(s)")
                        Spacer()
                        quickAddMenu
                        InfoPopover(
                            content: .shortcutWindowTitles,
                            isPresented: $showingWindowTitlesInfo
                        )
                        Button("Add") {
                            addShortcut()
                        }
                        .disabled(newWindowTitles.isEmpty)
                    }
                    
                    TextEditor(text: $newWindowTitles)
                        .font(.system(.body, design: .default))
                        .disableAutocorrection(true)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .formStyle(.grouped)
        .task { refreshSourceList() }
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
        .onAppear {
            for shortcut in shortcutManager.shortcutStorage.shortcuts {
                enabledStates[shortcut.id] = shortcut.isEnabled
            }
        }
        .onChange(of: shortcutManager.shortcutStorage.shortcuts) { newShortcuts in
            for shortcut in newShortcuts {
                enabledStates[shortcut.id] = shortcut.isEnabled
            }
        }
    }

    // MARK: - Computed Properties
    
    private var quickAddMenu: some View {
        Menu {
            ForEach(groupedSources.keys.sorted(), id: \.self) { appName in
                if let sources = groupedSources[appName] {
                    Menu(appName) {
                        ForEach(
                            sources.sorted(by: { ($0.title ?? "") < ($1.title ?? "") }),
                            id: \.windowID
                        ) { source in
                            Button(truncateTitle(source.title ?? "Untitled")) {
                                appendWindowTitle(source.title ?? "")
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Refresh") { refreshSourceList() }
        } label: {
            Image(systemName: "plus")
            Text("Quick Add...")
        }
        .id(sourceListVersion)
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

    private func prepareTitlesEditor(for shortcut: Shortcut) {
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

    // MARK: - Window Selection Helpers

    private func refreshSourceList() {
        Task { await updateAvailableSources() }
    }

    private func updateAvailableSources() async {
        do {
            let sources = try await sourceManager.getFilteredSources()
            availableSources = sources
            sourceListVersion = UUID()
            logger.debug("Shortcut window list updated: \(sources.count) windows")
        } catch {
            logger.logError(error, context: "Failed to retrieve source windows")
        }
    }

    private func appendWindowTitle(_ title: String) {
        if newWindowTitles.isEmpty {
            newWindowTitles = title
        } else {
            newWindowTitles.append(", \(title)")
        }
    }

    private var groupedSources: [String: [SCWindow]] {
        Dictionary(grouping: availableSources) {
            $0.owningApplication?.applicationName ?? "Unknown"
        }
    }

    private func truncateTitle(_ title: String) -> String {
        title.count > 50 ? title.prefix(50) + "..." : title
    }
}
