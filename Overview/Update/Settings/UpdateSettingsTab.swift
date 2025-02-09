/*
 Update/Settings/UpdateSettingsTab.swift
 Overview

 Created by William Pierce on 2/4/25.
*/

import Sparkle
import SwiftUI

struct UpdateSettingsTab: View {
    // Dependencies
    @ObservedObject private var updateViewModel: UpdateViewModel
    private let updater: SPUUpdater
    private let logger = AppLogger.settings

    // Private State
    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool
    @State private var showingUpdateInfo: Bool = false

    init(updater: SPUUpdater) {
        self.updater = updater
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        self._updateViewModel = ObservedObject(wrappedValue: UpdateViewModel(updater: updater))
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
                            updater.automaticallyChecksForUpdates = newValue
                        }

                    Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                        .disabled(!automaticallyChecksForUpdates)
                        .onChange(of: automaticallyDownloadsUpdates) { newValue in
                            updater.automaticallyDownloadsUpdates = newValue
                        }
                }

                HStack {
                    Spacer()
                    Button("Check Now") {
                        updateViewModel.checkForUpdates()
                    }
                    .disabled(!updateViewModel.canCheckForUpdates)
                }
            }
        }
        .formStyle(.grouped)
    }
}
