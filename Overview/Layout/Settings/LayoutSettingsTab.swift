/*
 Layout/Settings/LayoutSettingsTab.swift
 Overview

 Created by William Pierce on 2/24/25.
*/

import SwiftUI

struct LayoutJSON: Codable {
    var name: String
    var windows: [WindowState]
}

struct LayoutSettingsTab: View {
    // Dependencies
    @ObservedObject private var layoutManager: LayoutManager
    @StateObject private var windowManager: WindowManager
    private let logger = AppLogger.settings

    // Private State
    @State private var showingLayoutInfo: Bool = false
    @State private var showingApplyAlert: Bool = false
    @State private var showingUpdateAlert: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var layoutToModify: Layout? = nil
    @State private var newLayoutName: String = ""
    @State private var launchLayoutId: UUID? = nil

    // JSON Editor State
    @State private var isJSONEditorVisible: Bool = false
    @State private var layoutsJSON: String = ""
    @State private var jsonError: String? = nil
    init(windowManager: WindowManager, layoutManager: LayoutManager) {
        self.layoutManager = layoutManager
        self._windowManager = StateObject(wrappedValue: windowManager)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Window Layouts")
                        .font(.headline)

                    Spacer()

                    Button {
                        layoutsJSON = layoutsToJSON()
                        isJSONEditorVisible = true
                    } label: {
                        Text("[JSON]")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Update layout")

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
                                        HStack {
                                            Text(layout.name)
                                                .lineLimit(1)
                                                .help("Layout name")
                                        }
                                        Text("\(layout.windows.count) windows")
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
                        if !newLayoutName.isEmpty {
                            if layoutManager.isLayoutNameUnique(newLayoutName) {
                                _ = windowManager.saveLayout(name: newLayoutName)
                                newLayoutName = ""
                            } else {
                                logger.warning("Attempted to create layout with non-unique name")
                            }
                        }
                    }
                    .disabled(
                        newLayoutName.isEmpty || !layoutManager.isLayoutNameUnique(newLayoutName))
                }

                HStack {
                    Text("Apply layout on launch")
                    Spacer()
                    Picker("", selection: $launchLayoutId) {
                        Text("None").tag(nil as UUID?)
                        ForEach(layoutManager.layouts) { layout in
                            Text(layout.name).tag(layout.id as UUID?)
                        }
                    }
                    .frame(width: 160)
                    .onChange(of: launchLayoutId) { newValue in
                        layoutManager.setLaunchLayout(id: newValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchLayoutId = layoutManager.launchLayoutId
        }
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

                    if launchLayoutId == layout.id {
                        launchLayoutId = nil
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
            Form {
                VStack(spacing: 8) {
                    Text("Edit Layouts JSON")
                        .font(.headline)

                    if let error = jsonError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.callout)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }

                    TextEditor(text: $layoutsJSON)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 300)
                        .border(Color.secondary.opacity(0.2))
                        .padding()

                    HStack {
                        Button("Cancel") {
                            isJSONEditorVisible = false
                            jsonError = nil
                        }
                        .keyboardShortcut(.cancelAction)

                        Spacer()

                        Button("Save") {
                            applyJSON(layoutsJSON)
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding()
                }
                .frame(width: 400, height: 500)
                .padding()
            }.formStyle(.grouped)
        }
    }

    // MARK: - Actions

    // Convert layouts to JSON for editing
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

    // Validate and apply the edited JSON
    private func applyJSON(_ jsonString: String) {
        jsonError = nil

        do {
            // Validate JSON format
            guard let jsonData = jsonString.data(using: .utf8) else {
                jsonError = "Invalid text encoding"
                return
            }

            // Try to decode into layout objects
            let decoder = JSONDecoder()
            let layoutsFromJSON = try decoder.decode([LayoutJSON].self, from: jsonData)

            // Create new layouts with fresh UUIDs and timestamps
            let newLayouts = layoutsFromJSON.map { jsonLayout in
                Layout(name: jsonLayout.name, windows: jsonLayout.windows)
            }

            // Check for empty layout names
            if newLayouts.contains(where: { $0.name.isEmpty }) {
                jsonError = "Layout names cannot be empty"
                return
            }

            // Validate layout names
            if newLayouts.contains(where: { $0.name.isEmpty }) {
                jsonError = "Layout names cannot be empty"
                return
            }

            // Check for duplicate names
            let uniqueNames = Set(newLayouts.map { $0.name.lowercased() })
            if uniqueNames.count != newLayouts.count {
                jsonError = "Layout names must be unique (case-insensitive)"
                return
            }

            // Remove all existing layouts
            while !layoutManager.layouts.isEmpty {
                layoutManager.deleteLayout(id: layoutManager.layouts[0].id)
            }

            // Add the new layouts
            for layout in newLayouts {
                _ = windowManager.saveLayout(name: layout.name)

                // Get the newly created layout and update its windows
                if let newLayout = layoutManager.layouts.last {
                    layoutManager.updateLayout(
                        id: newLayout.id,
                        name: layout.name
                    )

                    // Need to update layout with windows separately
                    if let index = layoutManager.layouts.firstIndex(where: { $0.id == newLayout.id }
                    ) {
                        var updatedLayout = layoutManager.layouts[index]
                        updatedLayout.update(windows: layout.windows)
                        layoutManager.layouts[index] = updatedLayout
                        layoutManager.saveLayouts()
                    }
                }
            }

            // Close the editor
            isJSONEditorVisible = false
            logger.info("Successfully imported \(newLayouts.count) layouts from JSON")
        } catch {
            jsonError = "JSON Error: \(error.localizedDescription)"
            logger.logError(error, context: "Failed to import layouts from JSON")
        }
    }
}
