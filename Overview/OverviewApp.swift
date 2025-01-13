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
                    appDelegate.logger.logError(error, context: "Failed to create window from menu command")
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
    private var statusMenu: NSMenu?

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
            button.image = NSImage(systemSymbolName: "square.2.layers.3d.top.filled", accessibilityDescription: "Overview")
        }
        
        setupStatusMenu()
    }
    
    private func setupStatusMenu() {
        statusMenu = NSMenu()
        
        // New Window
        let newWindowItem = NSMenuItem(
            title: "New Window",
            action: #selector(createNewWindow),
            keyEquivalent: "n"
        )
        newWindowItem.keyEquivalentModifierMask = .command
        newWindowItem.target = self
        statusMenu?.addItem(newWindowItem)

        statusMenu?.addItem(NSMenuItem.separator())

        // Edit Mode
        let editModeItem = NSMenuItem(
            title: "Toggle Edit Mode",
            action: #selector(toggleEditMode),
            keyEquivalent: "e"
        )
        editModeItem.keyEquivalentModifierMask = .command
        editModeItem.target = self
        statusMenu?.addItem(editModeItem)
        
        
        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        statusMenu?.addItem(settingsItem)
        
        statusMenu?.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Overview",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        statusMenu?.addItem(quitItem)
        
        statusItem?.menu = statusMenu
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
    
    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
