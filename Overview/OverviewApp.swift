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

    // MARK: - View Components

    private var menuContent: some View {
        Group {
            newWindowButton
            Divider()
            editModeButton
            settingsButton
            Divider()
            versionText
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
