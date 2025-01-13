/*
 Settings/Views/Components/ResetSettingsButton.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct ResetSettingsButton: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var showingResetAlert = false

    var body: some View {
        Button("Reset All Settings") {
            showingResetAlert = true
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                settingsManager.resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to their default values.")
        }
    }
}
