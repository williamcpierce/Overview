/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 The main application entry point, providing the app's scene configuration
 and menu interface.
*/

import Sparkle
import SwiftUI

@main
struct OverviewApp: App {
    // Dependencies
    @NSApplicationDelegateAdaptor(OverviewAppDelegate.self) var appDelegate
    private let logger = AppLogger.interface

    // Private State
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // Computed Properties
    private var editModeBinding: Binding<Bool> {
        Binding(
            get: { appDelegate.previewManager.editModeEnabled },
            set: { appDelegate.previewManager.editModeEnabled = $0 }
        )
    }

    @available(macOS 14.0, *)
    private var openSettingsAction: OpenSettingsAction? {
        Environment(\.openSettings).wrappedValue
    }

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
                hotkeyStorage: appDelegate.hotkeyStorage,
                sourceManager: appDelegate.sourceManager,
                settingsManager: appDelegate.settingsManager,
                updateManager: appDelegate.updateManager
            )
        }
        .commands {
            appCommands
        }
    }

    // MARK: - Private Views

    private var menuContent: some View {
        Group {
            Button("New Window") {
                Task { @MainActor in
                    do {
                        try appDelegate.windowManager.createPreviewWindow()
                    } catch {
                        appDelegate.logger.logError(
                            error, context: "Failed to create window from menu")
                    }
                }
            }
            .keyboardShortcut("n")

            Divider()

            Button("Settings...") {
                openSettings()
            }
            .keyboardShortcut(",")

            Button("Toggle Edit Mode") {
                Task { @MainActor in
                    appDelegate.previewManager.editModeEnabled.toggle()
                }
            }
            .keyboardShortcut("e")

            Divider()

            Button("Quit Overview") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private var appCommands: some Commands {
        Group {
            CommandGroup(before: .newItem) {
                Button("New Window") {
                    Task { @MainActor in
                        do {
                            try appDelegate.windowManager.createPreviewWindow()
                        } catch {
                            appDelegate.logger.logError(
                                error, context: "Failed to create window from menu command")
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Edit") {
                Toggle("Edit Mode", isOn: editModeBinding)
                    .keyboardShortcut("e", modifiers: .command)
            }
        }
    }

    // MARK: - Private Methods

    private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        if #available(macOS 14.0, *), let action = openSettingsAction {
            action()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
