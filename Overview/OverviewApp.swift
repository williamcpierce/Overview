/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 The main application entry point, managing global state and window coordination
 through the app delegate and window service.
*/

import Sparkle
import SwiftUI

@main
struct OverviewApp: App {
    init() {
        SettingsMigrationUtility.migrateSettingsIfNeeded()
    }

    // App Delevate
    @NSApplicationDelegateAdaptor(OverviewAppDelegate.self) var appDelegate

    // Dependencies
    private var editModeBinding: Binding<Bool> {
        Binding(
            get: { appDelegate.previewManager.editModeEnabled },
            set: { appDelegate.previewManager.editModeEnabled = $0 }
        )
    }

    // Private State
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // Actions
    @available(macOS 14.0, *)
    private var openSettingsAction: OpenSettingsAction? {
        Environment(\.openSettings).wrappedValue
    }

    var body: some Scene {
        MenuBarExtra {
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
        } label: {
            Image(systemName: "square.2.layers.3d.top.filled")
        }

        Settings {
            SettingsView(
                hotkeyStorage: appDelegate.hotkeyStorage,
                sourceManager: appDelegate.sourceManager,
                settingsManager: appDelegate.settingsManager,
                updater: appDelegate.updaterController.updater
            )
        }
        .commands {
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

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *), let action = openSettingsAction {
            action()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

}

// MARK: - Application Delegate

@MainActor
final class OverviewAppDelegate: NSObject, NSApplicationDelegate {
    // Dependencies
    let logger = AppLogger.interface
    let hotkeyStorage = HotkeyStorage()
    let settingsManager: SettingsManager
    let sourceManager: SourceManager
    let previewManager: PreviewManager
    let hotkeyManager: HotkeyManager
    let updaterController: SPUStandardUpdaterController
    var windowManager: WindowManager!

    override init() {
        // Create updater controller first since we'll need it for settings
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        settingsManager = SettingsManager(
            hotkeyStorage: hotkeyStorage,
            updater: updaterController.updater
        )
        sourceManager = SourceManager(settingsManager: settingsManager)
        previewManager = PreviewManager(sourceManager: sourceManager)
        hotkeyManager = HotkeyManager(hotkeyStorage: hotkeyStorage, sourceManager: sourceManager)

        super.init()

        windowManager = WindowManager(
            previewManager: previewManager,
            sourceManager: sourceManager
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        Task {
            windowManager.restoreWindowStates()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowManager.saveWindowStates()
    }
}
