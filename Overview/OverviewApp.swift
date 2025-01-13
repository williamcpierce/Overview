/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 The main application entry point, managing global state and window coordination
 through the app delegate and window service.
*/

import Cocoa
import SwiftUI

@main
struct OverviewApp: App {
    @NSApplicationDelegateAdaptor(OverviewAppDelegate.self) var appDelegate
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some Scene {
        Settings {
            SettingsView(
                hotkeyStorage: appDelegate.hotkeyStorage,
                sourceManager: appDelegate.sourceManager,
                settingsManager: appDelegate.settingsManager
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
                do {
                    try appDelegate.windowManager.createPreviewWindow()
                } catch {
                    appDelegate.logger.logError(
                        error, context: "Failed to create window from menu command")
                    errorMessage = error.localizedDescription
                    showError = true
                }
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
    let hotkeyStorage = HotkeyStorage()
    let sourceManager: SourceManager
    let previewManager: PreviewManager
    let hotkeyManager: HotkeyManager
    let settingsManager: SettingsManager
    var windowManager: WindowManager!
    let logger = AppLogger.interface

    // MARK: - Private Properties
    private var statusItem: NSStatusItem?

    // MARK: - Initialization

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
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Create status bar item
        setupStatusBarItem()

        Task {
            windowManager.restoreWindowStates()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowManager.saveWindowStates()
    }

    // MARK: - Status Bar Setup

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "square.2.layers.3d.top.filled",
                accessibilityDescription: "Overview")
            button.action = #selector(showMenu)
            button.target = self
        }
    }

    @objc private func showMenu() {
        let menu = NSMenu()

        menu.addItem(
            withTitle: "New Window", action: #selector(createNewWindow), keyEquivalent: "n")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: "Toggle Edit Mode", action: #selector(toggleEditMode), keyEquivalent: "e")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Settings...", action: #selector(openSettings2), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: "Quit Overview", action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)  // Display the menu
    }

    // MARK: - Menu Actions

    @objc private func createNewWindow() {
        do {
            try windowManager.createPreviewWindow()
        } catch {
            logger.logError(error, context: "Failed to create window from menu")
        }
    }

    @objc private func toggleEditMode() {
        previewManager.editModeEnabled.toggle()
    }

    @objc private func openSettings2() {
        if #available(macOS 14.0, *) {
            @Environment(\.openSettings) var openSettings
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
