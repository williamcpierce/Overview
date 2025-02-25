/*
 Layout/Settings/LayoutSettingsTab.swift
 Overview

 Created by William Pierce on 2/24/25.
*/

import SwiftUI

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
                    InfoPopover(
                        content: .windowLayouts,
                        isPresented: $showingLayoutInfo
                    )
                }
                .padding(.bottom, 4)

                layoutListView

                HStack {
                    TextField("Layout name", text: $newLayoutName)
                        .textFieldStyle(.roundedBorder)

                    Button("Create") {
                        if !newLayoutName.isEmpty {
                            _ = windowManager.saveCurrentLayoutAsLayout(name: newLayoutName)
                            newLayoutName = ""
                        }
                    }
                    .disabled(newLayoutName.isEmpty)
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
        .frame(width: 384)
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
    }

    private var layoutListView: some View {
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
                                Image(systemName: "checkmark.arrow.trianglehead.counterclockwise")
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
    }
}
