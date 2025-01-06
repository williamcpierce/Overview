/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.
 
 The main application entry point, managing global state and window coordination
 through the app delegate and window service.
*/

import SwiftUI
import Cocoa

@main
struct OverviewApp: App {
    @NSApplicationDelegateAdaptor(OverviewAppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                appSettings: appDelegate.appSettings,
                sourceManager: appDelegate.sourceManager
            )
        }.commands {
            windowCommands
            editCommands
        }
    }

    // MARK: - Command Configuration

    private var windowCommands: some Commands {
        CommandGroup(before: .newItem) {
            Button("New Preview Window") {
                appDelegate.windowManager.createPreviewWindow()
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    private var editCommands: some Commands {
        CommandMenu("Edit") {
            Toggle("Edit Mode", isOn: editModeBinding)
            .keyboardShortcut("e", modifiers: .command)
        }
    }

    private var editModeBinding: Binding<Bool> {
        Binding(
            get: { appDelegate.previewManager.editModeEnabled },
            set: { appDelegate.previewManager.editModeEnabled = $0 }
        )
    }
}

// MARK: - App Delegate

@MainActor
final class OverviewAppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Public Properties
    let appSettings = AppSettings()
    let sourceManager: SourceManager
    let previewManager: PreviewManager
    let hotkeyManager: HotkeyManager
    var windowManager: WindowManager!

    // MARK: - Private Properties
    private let logger = AppLogger.interface

    // MARK: - Initialization

    override init() {
        sourceManager = SourceManager(appSettings: appSettings)
        previewManager = PreviewManager(sourceManager: sourceManager)
        hotkeyManager = HotkeyManager(appSettings: appSettings, sourceManager: sourceManager)

        super.init()

        windowManager = WindowManager(
            settings: appSettings,
            preview: previewManager,
            source: sourceManager
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
        Task {
            windowManager.restoreWindowStates()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowManager.saveWindowStates()
    }
}
