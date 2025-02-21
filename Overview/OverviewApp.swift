/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 The main application entry point, managing global state and window coordination
 through the app delegate and window service.
*/

import SwiftUI

@main
struct OverviewApp: App {
    // Dependencies
    @NSApplicationDelegateAdaptor(OverviewAppDelegate.self) var appDelegate
    private let logger = AppLogger.interface

    init() {
        SettingsMigrationUtility.migrateSettingsIfNeeded()
    }

    var body: some Scene {
        MenuBarExtra {
            menuContent
        } label: {
            Image(systemName: "square.2.layers.3d.top.filled")
        }

        Settings {
            SettingsView(
                sourceManager: appDelegate.sourceManager,
                settingsManager: appDelegate.settingsManager,
                updateManager: appDelegate.updateManager
            )
        }
        .commands {
            commandGroup
        }
    }

    private var menuContent: some View {
        Group {
            newWindowButton
            Divider()
            editModeButton
            Divider()
            helpMenu
            Divider()
            settingsButton
            updateButton
            quitButton
        }
    }

    private var newWindowButton: some View {
        Button("New Window") {
            newWindow(context: "menu bar")
        }
        .keyboardShortcut("n")
    }

    private var editModeButton: some View {
        Button("Toggle Edit Mode") {
            toggleEditMode()
        }
        .keyboardShortcut("e")
    }

    private var settingsButton: some View {
        Button("Settings...") {
            openSettings()
        }
        .keyboardShortcut(",")
    }

    private var versionText: some View {
        Group {
            if let version: String = getAppVersion() {
                Text("Version \(version)")
            }
        }
    }

    private var updateButton: some View {
        Button("Check for Updates...") {
            appDelegate.updateManager.checkForUpdates()
        }
    }

    private var quitButton: some View {
        Button("Quit Overview") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var helpMenu: some View {

        Menu("Help") {
            Button {
                openDiscord()
            } label: {
                Image(systemName: "bubble.fill")
                Text("Join Discord")
            }

            Button {
                openBugReport()
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Report Bug")
            }

            Button {
                openFeatureRequest()
            } label: {
                Image(systemName: "lightbulb.fill")
                Text("Request Feature")
            }

            Divider()

            versionText
            Button("Diagnostic Report...") {
                generateDiagnosticReport()
            }
            Button("Restart") {
                restartApp()
            }.keyboardShortcut("r")
        }
    }

    private func openDiscord() {
        if let url = URL(string: "https://discord.gg/ekKMnejQbA") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openBugReport() {
        if let url = URL(string: "https://github.com/williamcpierce/Overview/issues/new?labels=bug")
        {
            NSWorkspace.shared.open(url)
        }
    }

    private func openFeatureRequest() {
        if let url = URL(
            string: "https://github.com/williamcpierce/Overview/issues/new?labels=enhancement")
        {
            NSWorkspace.shared.open(url)
        }
    }

    private func generateDiagnosticReport() {
        Task {
            do {
                let report = try await DiagnosticService.shared.generateDiagnosticReport()
                let fileURL = try await DiagnosticService.shared.saveDiagnosticReport(report)

                // Show success alert and reveal in Finder
                NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: "")
                logger.info("Diagnostic report generated and saved successfully")
            } catch {
                logger.logError(error, context: "Failed to generate diagnostic report")
                // Show error alert
                let alert = NSAlert()
                alert.messageText = "Failed to Generate Report"
                alert.informativeText = "An error occurred while generating the diagnostic report."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    @MainActor
    private func restartApp() {
        logger.debug("Initiating application restart")

        let process = Process()
        process.executableURL = Bundle.main.executableURL
        process.arguments = []

        do {
            try process.run()
            NSApplication.shared.terminate(nil)
        } catch {
            logger.logError(error, context: "Failed to restart application")
        }
    }

    // MARK: - Commands

    private var commandGroup: some Commands {
        Group {
            CommandGroup(before: .newItem) {
                Button("New Window") {
                    newWindow(context: "file menu")
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Edit") {
                Button("Toggle Edit Mode") {
                    toggleEditMode()
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }
    }

    // MARK: - Private Methods

    private func getAppVersion() -> String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    private func newWindow(context: String) {
        Task { @MainActor in
            do {
                try appDelegate.windowManager.createPreviewWindow()
            } catch {
                logger.logError(error, context: "Failed to create window from \(context)")
            }
        }
    }

    private func toggleEditMode() {
        Task { @MainActor in
            appDelegate.previewManager.editModeEnabled.toggle()
        }
    }

    private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if #available(macOS 14.0, *) {
            let openSettings: OpenSettingsAction = Environment(\.openSettings).wrappedValue
            openSettings()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
