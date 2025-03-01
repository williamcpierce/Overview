/*
 Update/Settings/UpdateSettingsTab.swift
 Overview

 Created by William Pierce on 2/4/25.
*/

import Defaults
import Sparkle
import SwiftUI

struct UpdateSettingsTab: View {
    // Dependencies
    @ObservedObject private var updateManager: UpdateManager
    private let logger = AppLogger.settings

    // Private State
    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool
    @State private var showingUpdateInfo: Bool = false

    // Settings
    @Default(.enableBetaUpdates) private var enableBetaUpdates

    init(updateManager: UpdateManager) {
        self.updateManager = updateManager
        self.automaticallyChecksForUpdates = updateManager.updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updateManager.updater.automaticallyDownloadsUpdates
    }

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
                    Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                        .onChange(of: automaticallyChecksForUpdates) { newValue in
                            updateManager.updater.automaticallyChecksForUpdates = newValue
                        }

                    Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                        .disabled(!automaticallyChecksForUpdates)
                        .onChange(of: automaticallyDownloadsUpdates) { newValue in
                            updateManager.updater.automaticallyDownloadsUpdates = newValue
                        }

                    Toggle("Enable beta updates", isOn: $enableBetaUpdates).disabled(true)
                        .help("All updates are beta updates currently, this setting has no effect.")
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
}
