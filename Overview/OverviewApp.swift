/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 The main application entry point that configures and coordinates core services,
 manages the application lifecycle, and sets up the primary user interface.
*/

import SwiftUI
import Cocoa

@main
struct OverviewApp: App {
    // MARK: - Core Services
    
    @StateObject private var appSettings: AppSettings
    @StateObject private var sourceManager: SourceManager
    @StateObject private var previewManager: PreviewManager
    @StateObject private var hotkeyManager: HotkeyManager
    
    private let windowService: WindowService
    private let appDelegate: AppDelegate?
    private let logger = AppLogger.interface
    
    init() {
        logger.debug("Initializing core application services")
        
        // Initialize core services
        let settings = AppSettings()
        let source = SourceManager(appSettings: settings)
        let preview = PreviewManager(sourceManager: source)
        let hotkey = HotkeyManager(appSettings: settings, sourceManager: source)
        let windowService = WindowService(settings: settings, preview: preview, source: source)
        
        // Create StateObjects
        self._appSettings = StateObject(wrappedValue: settings)
        self._sourceManager = StateObject(wrappedValue: source)
        self._previewManager = StateObject(wrappedValue: preview)
        self._hotkeyManager = StateObject(wrappedValue: hotkey)
        self.windowService = windowService
        
        // Initialize app delegate if needed
        if NSApplication.shared.delegate == nil {
            let delegate = AppDelegate(windowService: windowService)
            self.appDelegate = delegate
            NSApplication.shared.delegate = delegate
        } else {
            self.appDelegate = nil
        }
        
        // Configure application
        configureApplication(windowService)
        
        logger.info("Application services initialized successfully")
    }
    
    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
        .commands {
            CommandGroup(before: .newItem) {
                Button("New Preview Window") {
                    windowService.createPreviewWindow()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Close All Windows") {
                    windowService.closeAllPreviewWindows()
                }
                .keyboardShortcut("w", modifiers: [.command, .option])
            }
            
            CommandMenu("Edit") {
                Toggle("Edit Mode", isOn: $previewManager.editModeEnabled)
            }
        }
        
        Settings {
            SettingsView(
                appSettings: appSettings,
                sourceManager: sourceManager
            )
        }
    }
    
    private func configureApplication(_ windowService: WindowService) {
        // Restore window state
        DispatchQueue.main.async {
            windowService.restoreWindowStates()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowService: WindowService
    private let logger = AppLogger.interface
    
    init(windowService: WindowService) {
        self.windowService = windowService
        super.init()
        configureTerminationHandler()
    }
    
    private func configureTerminationHandler() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc func applicationWillTerminate(_ notification: Notification) {
        windowService.saveWindowStates()
        logger.info("Application terminating, window states saved")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
