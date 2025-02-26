/*
 AutoCapture/Settings/AutoCaptureSettingsTab.swift
 Overview

 Created by William Pierce on 2/25/25.
*/

import SwiftUI

struct AutoCaptureSettingsTab: View {
    // Dependencies
    @ObservedObject var autoCaptureService: AutoCaptureService
    private let logger = AppLogger.settings

    // Private State
    @State private var newAppName: String = ""
    @State private var showingAutoCaptureInfo: Bool = false
    @State private var showingResetAlert: Bool = false

    // Auto-Capture Settings
    @AppStorage(AutoCaptureSettingsKeys.enabled)
    private var autoCaptureEnabled = AutoCaptureSettingsKeys.defaults.enabled
    
    // We need to handle array storage manually
    @State private var autoCaptureApplications: [String] = []
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Auto-Capture")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .autoCapture,
                        isPresented: $showingAutoCaptureInfo
                    )
                }
                .padding(.bottom, 4)

                Toggle("Enable auto-capture for applications", isOn: $autoCaptureEnabled)
                
                VStack(alignment: .leading) {
                    Text("Applications")
                        .fontWeight(.medium)
                        .padding(.bottom, 4)
                    
                    if autoCaptureApplications.isEmpty {
                        List {
                            Text("No applications configured")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        List(autoCaptureApplications, id: \.self) { appName in
                            HStack {
                                Text(appName)
                                    .lineLimit(1)
                                    .help(appName)
                                Spacer()
                                Button(action: { removeApplication(appName) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                HStack {
                    TextField("Application name", text: $newAppName)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                    Button("Add") {
                        addApplication()
                    }
                    .disabled(newAppName.isEmpty)
                }

                Button("Reset Character Positions") {
                    showingResetAlert = true
                }
                .alert("Reset Character Positions", isPresented: $showingResetAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset", role: .destructive) {
                        autoCaptureService.resetCharacterPositions()
                    }
                } message: {
                    Text("This will delete all saved window positions for characters. You'll need to reposition windows for each character.")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions

    private func addApplication() {
        guard !newAppName.isEmpty else { return }
        
        if !autoCaptureApplications.contains(newAppName) {
            autoCaptureApplications.append(newAppName)
            saveApplications()
            logger.info("Added application to auto-capture list: '\(newAppName)'")
        }
        
        newAppName = ""
    }

    private func removeApplication(_ appName: String) {
        if let index = autoCaptureApplications.firstIndex(of: appName) {
            autoCaptureApplications.remove(at: index)
            saveApplications()
            logger.info("Removed application from auto-capture list: '\(appName)'")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadApplications() {
        guard let data = UserDefaults.standard.data(forKey: AutoCaptureSettingsKeys.applications) else {
            autoCaptureApplications = AutoCaptureSettingsKeys.defaults.applications
            return
        }
        
        do {
            autoCaptureApplications = try JSONDecoder().decode([String].self, from: data)
        } catch {
            logger.logError(error, context: "Failed to decode auto-capture applications")
            autoCaptureApplications = AutoCaptureSettingsKeys.defaults.applications
        }
    }
    
    private func saveApplications() {
        do {
            let data = try JSONEncoder().encode(autoCaptureApplications)
            UserDefaults.standard.set(data, forKey: AutoCaptureSettingsKeys.applications)
        } catch {
            logger.logError(error, context: "Failed to encode auto-capture applications")
        }
    }
}
