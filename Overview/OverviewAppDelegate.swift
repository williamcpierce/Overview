/*
 OverviewAppDelegate.swift
 Overview

 Created by William Pierce on 9/15/24.

 The application delegate managing global state coordination and window management.
*/

import Sparkle
import SwiftUI

@MainActor
final class OverviewAppDelegate: NSObject, NSApplicationDelegate {
    // Dependencies
    let logger = AppLogger.interface
    let hotkeyStorage = HotkeyStorage()
    let settingsManager: SettingsManager
    let sourceManager: SourceManager
    let previewManager: PreviewManager
    let hotkeyManager: HotkeyManager
    let updateManager: UpdateManager
    var windowManager: WindowManager!

    override init() {
        updateManager = UpdateManager()
        settingsManager = SettingsManager(
            hotkeyStorage: hotkeyStorage,
            updateManager: updateManager
        )
        sourceManager = SourceManager(settingsManager: settingsManager)
        previewManager = PreviewManager(sourceManager: sourceManager)
        hotkeyManager = HotkeyManager(hotkeyStorage: hotkeyStorage, sourceManager: sourceManager)

        super.init()

        windowManager = WindowManager(
            previewManager: previewManager,
            sourceManager: sourceManager
        )

        setupObservers()
    }

    // MARK: - Lifecycle Methods

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.debug("Application finished launching")
        NSApp.setActivationPolicy(.accessory)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsWindowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        Task {
            if !SetupCoordinator.shared.shouldShowSetup {
                windowManager.restoreWindowStates()
            }
            await SetupCoordinator.shared.startSetupIfNeeded()
            logger.info("Application initialization completed")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.debug("Application preparing to terminate")
        windowManager.saveWindowStates()
    }

    // MARK: - Private Methods

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func settingsWindowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              isSettingsWindow(window) else { return }
              
        let hasOpenSettingsWindows = NSApp.windows.contains { isSettingsWindow($0) && $0 != window }
        if !hasOpenSettingsWindows {
            NSApp.setActivationPolicy(.accessory)
            logger.debug("Last settings window closing, hiding Dock icon")
        }
    }
    
    private func isSettingsWindow(_ window: NSWindow) -> Bool {
        window.styleMask.rawValue == 32771
    }
}
