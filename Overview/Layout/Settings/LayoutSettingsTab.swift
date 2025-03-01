/*
 Layout/Settings/LayoutSettingsTab.swift
 Overview

 Created by William Pierce on 2/24/25.

 Provides a user interface for creating, managing, and applying window layouts.
*/

import Defaults
import SwiftUI

struct LayoutJSON: Codable {
    var name: String
    var windows: [WindowState]
}

struct LayoutSettingsTab: View {
    // Dependencies
    @ObservedObject private var layoutManager: LayoutManager
    @ObservedObject private var windowManager: WindowManager
    private let logger = AppLogger.settings

    // Private State
    @State private var showingLayoutInfo: Bool = false
    @State private var showingApplyAlert: Bool = false
    @State private var showingUpdateAlert: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var layoutToModify: Layout? = nil
    @State private var newLayoutName: String = ""
    @State private var selectedLayoutNameBeforeJSON: String? = nil

    // JSON Editor State
    @State private var isJSONEditorVisible: Bool = false
    @State private var layoutsJSON: String = ""
    @State private var jsonError: String? = nil

    // Layout Settings
    @Default(.closeWindowsOnApply) private var closeWindowsOnApply
    @Default(.launchLayoutUUID) private var launchLayoutUUID

    init(windowManager: WindowManager, layoutManager: LayoutManager) {
        self.layoutManager = layoutManager
        self.windowManager = windowManager
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Window Layouts")
                        .font(.headline)

                    Spacer()

                    Button(action: {
                        prepareJSONEditor()
                    }) {
                        Image(systemName: "ellipsis.curlybraces")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit layouts as JSON")

                    InfoPopover(
                        content: .windowLayouts,
                        isPresented: $showingLayoutInfo
                    )
                }
                .padding(.bottom, 4)

                VStack {
                    List {
                        if layoutManager.layouts.isEmpty {
                            Text("No layouts saved")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(layoutManager.layouts) { layout in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(layout.name)
                                            .lineLimit(1)
                                        Text(
                                            "\(layout.windows.count) \(layout.windows.count == 1 ? "window" : "windows")"
                                        )
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button {
                                        layoutToModify = layout
                                        showingApplyAlert = true
                                    } label: {
                                        Image(
                                            systemName:
                                                "checkmark.arrow.trianglehead.counterclockwise"
                                        )
                                        .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Apply layout")

                                    Button {
                                        layoutToModify = layout
                                        showingUpdateAlert = true
                                    } label: {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Update layout")

                                    Button {
                                        layoutToModify = layout
                                        showingDeleteAlert = true
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete layout")
                                }
                            }
                        }
                    }
                }

                HStack {
                    TextField("Layout name", text: $newLayoutName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: newLayoutName) { newValue in
                            newLayoutName = newValue.trimmingCharacters(in: .whitespaces)
                        }

                    Button("Create") {
                        createLayout()
                    }
                    .disabled(
                        newLayoutName.isEmpty || !layoutManager.isLayoutNameUnique(newLayoutName))
                }
            }

            VStack {
                HStack {
                    Text("Apply layout on launch")
                    Spacer()
                    Picker("", selection: $launchLayoutUUID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(layoutManager.layouts) { layout in
                            Text(layout.name).tag(layout.id as UUID?)
                        }
                    }
                    .frame(width: 160)
                }

                Toggle("Close all windows when applying layouts", isOn: $closeWindowsOnApply)
            }
        }
        .formStyle(.grouped)
        .alert("Apply Layout", isPresented: $showingApplyAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Apply") {
                if let layout = layoutToModify {
                    windowManager.applyLayout(layout)
                }
                layoutToModify = nil
            }
        } message: {
            if let layout = layoutToModify {
                Text("Apply layout '\(layout.name)'? This will close all current windows.")
            } else {
                Text("Select a layout to apply")
            }
        }
        .alert("Update Layout", isPresented: $showingUpdateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Update") {
                if let layout = layoutToModify {
                    layoutManager.updateLayout(id: layout.id)
                }
                layoutToModify = nil
            }
        } message: {
            if let layout = layoutToModify {
                Text("Update layout '\(layout.name)' with current window layout?")
            } else {
                Text("Select a layout to update")
            }
        }
        .alert("Delete Layout", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let layout = layoutToModify {
                    layoutManager.deleteLayout(id: layout.id)
                    if launchLayoutUUID == layout.id {
                        launchLayoutUUID = nil
                    }
                }
                layoutToModify = nil
            }
        } message: {
            if let layout = layoutToModify {
                Text("Delete layout '\(layout.name)'? This cannot be undone.")
            } else {
                Text("Select a layout to delete")
            }
        }
        .sheet(isPresented: $isJSONEditorVisible) {
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

                TextEditor(text: $layoutsJSON)
                    .font(.system(.body, design: .monospaced))
                    .disableAutocorrection(true)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 300)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding()
            .safeAreaInset(edge: .bottom) {
                VStack {
                    Divider()
                    HStack(spacing: 12) {
                        Spacer()
                        Button("Cancel") {
                            isJSONEditorVisible = false
                            jsonError = nil
                        }
                        .keyboardShortcut(.cancelAction)
                        Button("Save") {
                            applyJSON(layoutsJSON)
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
            .frame(width: 600)
        }
    }

    // MARK: - Actions

    private func prepareJSONEditor() {
        if let launchUUID: UUID = launchLayoutUUID {
            selectedLayoutNameBeforeJSON =
                layoutManager.layouts.first {
                    $0.id == launchUUID
                }?.name
        } else {
            selectedLayoutNameBeforeJSON = nil
        }

        layoutsJSON = layoutsToJSON()
        isJSONEditorVisible = true
    }
    private func createLayout() {
        guard !newLayoutName.isEmpty, layoutManager.createLayout(name: newLayoutName) != nil
        else {
            logger.warning("Attempted to create layout with empty or non-unique name")
            return
        }
        newLayoutName = ""
    }

    private func layoutsToJSON() -> String {
        let layoutsForJSON = layoutManager.layouts.map { layout in
            LayoutJSON(name: layout.name, windows: layout.windows)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let jsonData = try encoder.encode(layoutsForJSON)
            return String(data: jsonData, encoding: .utf8) ?? "[]"
        } catch {
            logger.logError(error, context: "Failed to convert layouts to JSON")
            return "[]"
        }
    }

    private func applyJSON(_ jsonString: String) {
        jsonError = nil

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
            let layoutsFromJSON = try decoder.decode([LayoutJSON].self, from: jsonData)

            if !validateLayouts(layoutsFromJSON) {
                return
            }

            importLayouts(layoutsFromJSON)
            restoreLaunchSetting()
            isJSONEditorVisible = false
            logger.info("Successfully imported \(layoutsFromJSON.count) layouts from JSON")
        } catch {
            jsonError = "JSON Error: \(error.localizedDescription)"
            logger.logError(error, context: "Failed to import layouts from JSON")
        }
    }

    // MARK: - Helper Methods

    private func validateLayouts(_ layouts: [LayoutJSON]) -> Bool {
        if layouts.contains(where: { $0.name.isEmpty }) {
            jsonError = "Layout names cannot be empty"
            return false
        }
        let uniqueNames = Set(layouts.map { $0.name.lowercased() })
        if uniqueNames.count != layouts.count {
            jsonError = "Layout names must be unique (case-insensitive)"
            return false
        }
        return true
    }

    private func importLayouts(_ layoutsFromJSON: [LayoutJSON]) {
        while !layoutManager.layouts.isEmpty {
            layoutManager.deleteLayout(id: layoutManager.layouts[0].id)
        }

        for layout in layoutsFromJSON {
            _ = windowManager.saveLayout(name: layout.name)

            if let newLayout = layoutManager.layouts.last {
                layoutManager.updateLayout(id: newLayout.id, name: layout.name)

                if let index = layoutManager.layouts.firstIndex(where: { $0.id == newLayout.id }) {
                    var updatedLayout = layoutManager.layouts[index]
                    updatedLayout.update(windows: layout.windows)
                    layoutManager.layouts[index] = updatedLayout
                }
            }
        }
    }

    private func restoreLaunchSetting() {
        if let previousLayoutName: String = selectedLayoutNameBeforeJSON,
            let matchingLayout = layoutManager.layouts.first(where: {
                $0.name == previousLayoutName
            })
        {
            launchLayoutUUID = matchingLayout.id
            logger.debug("Restored launch layout setting to '\(previousLayoutName)'")
        } else {
            launchLayoutUUID = nil
            logger.debug("Previous launch layout no longer exists, cleared setting")
        }
    }
}
