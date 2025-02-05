/*
 Update/Settings/UpdateSettingsTab.swift
 Overview

 Created by William Pierce on 2/4/25.
*/

import SwiftUI

struct UpdateSettingsTab: View {
    // Dependencies
    @ObservedObject var updateManager: UpdateManager
    private let logger = AppLogger.settings

    // Private State
    @State private var showingUpdateInfo = false

    // Update Settings
    @AppStorage(UpdateSettingsKeys.automaticUpdateChecks)
    private var automaticUpdateChecks = UpdateSettingsKeys.defaults.automaticUpdateChecks

    @AppStorage(UpdateSettingsKeys.automaticDownloads)
    private var automaticDownloads = UpdateSettingsKeys.defaults.automaticDownloads

    @AppStorage(UpdateSettingsKeys.betaUpdates)
    private var betaUpdates = UpdateSettingsKeys.defaults.betaUpdates

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Software Updates")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .updates,
                        isPresented: $showingUpdateInfo
                    )
                }
                .padding(.bottom, 4)

                VStack {
                    Toggle("Automatically check for updates", isOn: $automaticUpdateChecks)

                    if automaticUpdateChecks {
                        Toggle(
                            "Automatically download and install updates", isOn: $automaticDownloads)
                    }

                    Toggle("Include beta releases", isOn: $betaUpdates)
                        .onChange(of: betaUpdates) { _ in
                            updateFeedURL()
                        }
                }

                HStack {
                    Spacer()
                    Button("Check Now") {
                        updateManager.checkForUpdates()
                    }
                    .disabled(!updateManager.canCheckForUpdates)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Private Methods

    private func updateFeedURL() {
        let feedURL =
            betaUpdates
            ? UpdateSettingsKeys.defaults.betaUpdateURL
            : UpdateSettingsKeys.defaults.stableUpdateURL

        UserDefaults.standard.set(feedURL, forKey: UpdateSettingsKeys.betaUpdates)
        logger.info("Updated feed URL: \(feedURL)")
    }
}
