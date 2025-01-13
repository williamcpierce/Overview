/*
 Settings/Components/ResetSettingsButton.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct ResetSettingsButton: View {
    // Dependencies
    @ObservedObject var settingsManager: SettingsManager

    // Private State
    @State private var showingResetAlert: Bool = false

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
