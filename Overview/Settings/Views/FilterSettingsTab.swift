/*
 Settings/Views/FilterSettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import SwiftUI

struct FilterSettingsTab: View {
    @ObservedObject var appSettings: AppSettings
    @State private var newAppFilterName = ""
    private let logger = AppLogger.settings

    var body: some View {
        if #available(macOS 13.0, *) {
            Form {
                formContent
            }
            .formStyle(.grouped)
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    formContent
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }

    @ViewBuilder
    private var formContent: some View {
        Section {
            Text("Selection Dropdown Filter")
                .font(.headline)
                .padding(.bottom, 4)

            Picker("Filter Mode", selection: $appSettings.filterBlocklist) {
                Text("Blocklist").tag(true)
                Text("Allowlist").tag(false)
            }
            .pickerStyle(.segmented)

            if appSettings.filterAppNames.isEmpty {
                Text("No applications configured")
                    .foregroundColor(.secondary)
            } else {
                ForEach(appSettings.filterAppNames, id: \.self) { appName in
                    HStack {
                        Text(appName)
                        Spacer()
                        Button(action: {
                            removeAppFilterName(appName)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                TextField("App Name", text: $newAppFilterName)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                Button("Add") {
                    addAppFilterName()
                }
                .disabled(newAppFilterName.isEmpty)
            }
        }
    }

    private func addAppFilterName() {
        guard !newAppFilterName.isEmpty else { return }
        logger.info("Adding app filter: '\(newAppFilterName)'")
        appSettings.filterAppNames.append(newAppFilterName)
        newAppFilterName = ""
    }

    private func removeAppFilterName(_ appName: String) {
        if let index = appSettings.filterAppNames.firstIndex(of: appName) {
            appSettings.filterAppNames.remove(at: index)
            logger.info("Removed app filter: '\(appName)'")
        }
    }
}
