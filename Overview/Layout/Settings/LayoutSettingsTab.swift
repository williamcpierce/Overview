/*
 Layout/Settings/LayoutSettingsTab.swift
 Overview

 Created by William Pierce on 2/24/25.

 Provides a user interface for creating, managing, and applying window layouts.
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
    @State private var selectedLayoutNameBeforeJSON: String? = nil

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
                        Text("[JSON]")
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

                layoutListView
                layoutCreationControls
                launchLayoutSelector
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
        if let launchId: UUID = launchLayoutId {
            selectedLayoutNameBeforeJSON =
                layoutManager.layouts.first {
                    $0.id == launchId
                }?.name
        } else {
            selectedLayoutNameBeforeJSON = nil
        }

        layoutsJSON = layoutsToJSON()
        isJSONEditorVisible = true
    }

    private func createLayout() {
        if !newLayoutName.isEmpty && layoutManager.isLayoutNameUnique(newLayoutName) {
            _ = windowManager.saveLayout(name: newLayoutName)
            newLayoutName = ""
        } else {
            logger.warning("Attempted to create layout with empty or non-unique name")
        }
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

        do {
            guard let jsonData = jsonString.data(using: .utf8) else {
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

        let uniqueNames: Set<String> = Set(layouts.map { $0.name.lowercased() })
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

        for layout: LayoutJSON in layoutsFromJSON {
            _ = windowManager.saveLayout(name: layout.name)

            if let newLayout = layoutManager.layouts.last {
                layoutManager.updateLayout(id: newLayout.id, name: layout.name)

                if let index = layoutManager.layouts.firstIndex(where: { $0.id == newLayout.id }) {
                    var updatedLayout = layoutManager.layouts[index]
                    updatedLayout.update(windows: layout.windows)
                    layoutManager.layouts[index] = updatedLayout
                    layoutManager.saveLayouts()
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
            launchLayoutId = matchingLayout.id
            layoutManager.setLaunchLayout(id: matchingLayout.id)
            logger.debug("Restored launch layout setting to '\(previousLayoutName)'")
        } else {
            launchLayoutId = nil
            layoutManager.setLaunchLayout(id: nil)
            logger.debug("Previous launch layout no longer exists, cleared setting")
        }
    }
}
