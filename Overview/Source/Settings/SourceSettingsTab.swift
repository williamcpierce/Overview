/*
 Source/Settings/SourceSettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct SourceSettingsTab: View {
    // Dependencies
    @ObservedObject var settingsManager: SettingsManager
    private let logger = AppLogger.settings

    // Private State
    @State private var newAppName: String = ""
    @State private var showingSourceFilterInfo: Bool = false

    // App Filter Settings
    @AppStorage(SourceSettingsKeys.filterMode)
    private var filterMode = SourceSettingsKeys.defaults.filterMode

    var body: some View {
        Form {

            // MARK: - App Filter Section

            Section {
                HStack {
                    Text("Source App Filter")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .sourceFilter,
                        isPresented: $showingSourceFilterInfo,
                        showWarning: filterMode == FilterMode.allowlist
                    )
                }
                .padding(.bottom, 4)

                VStack {
                    if settingsManager.filterAppNames.isEmpty {
                        List {
                            Text("No applications configured")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        List(settingsManager.filterAppNames, id: \.self) { appName in
                            HStack {
                                Text(appName)
                                Spacer()
                                Button(action: { removeAppFilter(appName) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Picker("Filter Mode", selection: $filterMode) {
                    Text("Blocklist").tag(FilterMode.blocklist)
                    Text("Allowlist").tag(FilterMode.allowlist)
                }
                .pickerStyle(.segmented)

                HStack {
                    TextField("App Name", text: $newAppName)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                    Button("Add") {
                        addAppFilter()
                    }
                    .disabled(newAppName.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions

    private func addAppFilter() {
        guard !newAppName.isEmpty else { return }
        logger.info("Adding app filter: '\(newAppName)'")
        settingsManager.filterAppNames.append(newAppName)
        newAppName = ""
    }

    private func removeAppFilter(_ appName: String) {
        if let index = settingsManager.filterAppNames.firstIndex(of: appName) {
            settingsManager.filterAppNames.remove(at: index)
            logger.info("Removed app filter: '\(appName)'")
        }
    }
}
