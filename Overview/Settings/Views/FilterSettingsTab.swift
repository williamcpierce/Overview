/*
 Settings/Views/FilterSettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct FilterSettingsTab: View {
    // MARK: - State
    @State private var filterAppNames: [String] = []
    @State private var newAppName = ""
    @AppStorage(FilterSettingsKeys.isBlocklist)
    private var isBlocklist = FilterSettingsKeys.defaults.isBlocklist
    private let logger = AppLogger.settings

    // MARK: - Init
    init() {
        if let storedNames = UserDefaults.standard.array(forKey: FilterSettingsKeys.appNames)
            as? [String]
        {
            _filterAppNames = State(initialValue: storedNames)
        } else {
            _filterAppNames = State(initialValue: FilterSettingsKeys.defaults.appNames)
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Source Selection Dropdown")
                        .font(.headline)
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 4)

                VStack {
                    if filterAppNames.isEmpty {
                        List {
                            Text("No applications filtered")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        List(filterAppNames, id: \.self) { appName in
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

                Picker("Filter Mode", selection: $isBlocklist) {
                    Text("Blocklist").tag(true)
                    Text("Allowlist").tag(false)
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

    private func addAppFilter() {
        guard !newAppName.isEmpty else { return }
        logger.info("Adding app filter: '\(newAppName)'")
        filterAppNames.append(newAppName)
        UserDefaults.standard.set(filterAppNames, forKey: FilterSettingsKeys.appNames)
        newAppName = ""
    }

    private func removeAppFilter(_ appName: String) {
        if let index = filterAppNames.firstIndex(of: appName) {
            filterAppNames.remove(at: index)
            UserDefaults.standard.set(filterAppNames, forKey: FilterSettingsKeys.appNames)
            logger.info("Removed app filter: '\(appName)'")
        }
    }
}
