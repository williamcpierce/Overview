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
    @NSApplicationDelegateAdaptor(OverviewAppDelegate.self) var appDelegate
    @State private var showError = false
    @State private var errorMessage = ""

    @available(macOS 14.0, *)
    private var openSettingsAction: OpenSettingsAction? {
        Environment(\.openSettings).wrappedValue
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *), let action = openSettingsAction {
            action()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
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
                settingsManager: appDelegate.settingsManager
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

    private var editModeBinding: Binding<Bool> {
        Binding(
            get: { appDelegate.previewManager.editModeEnabled },
            set: { appDelegate.previewManager.editModeEnabled = $0 }
        )
    }
}

@MainActor
final class OverviewAppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Public Properties
    let hotkeyStorage = HotkeyStorage()
    let sourceManager: SourceManager
    let previewManager: PreviewManager
    let hotkeyManager: HotkeyManager
    let settingsManager: SettingsManager
    var windowManager: WindowManager!
    let logger = AppLogger.interface

    override init() {
        sourceManager = SourceManager()
        previewManager = PreviewManager(sourceManager: sourceManager)
        hotkeyManager = HotkeyManager(hotkeyStorage: hotkeyStorage, sourceManager: sourceManager)
        settingsManager = SettingsManager(hotkeyStorage: hotkeyStorage)

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

    // MARK: - NSApplicationDelegate

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
