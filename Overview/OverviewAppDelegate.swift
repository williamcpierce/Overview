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
    let settingsManager: SettingsManager
    let sourceManager: SourceManager
    let previewManager: PreviewManager
    let shortcutManager: ShortcutManager
    let updateManager: UpdateManager
    let permissionManager: PermissionManager
    var windowManager: WindowManager!

    override init() {
        updateManager = UpdateManager()
        permissionManager = PermissionManager()

        settingsManager = SettingsManager(
            updateManager: updateManager
        )
        sourceManager = SourceManager(
            settingsManager: settingsManager,
            permissionManager: permissionManager
        )
        previewManager = PreviewManager(
            sourceManager: sourceManager,
            permissionManager: permissionManager
        )
        shortcutManager = ShortcutManager(
            sourceManager: sourceManager
        )

        super.init()

        windowManager = WindowManager(
            previewManager: previewManager,
            sourceManager: sourceManager,
            permissionManager: permissionManager
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
            do {
                try await permissionManager.ensurePermission()
                windowManager.restoreWindowStates()
                logger.info("Application initialization completed")
            } catch {
                logger.logError(error, context: "Failed to ensure permissions during launch")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.debug("Application preparing to terminate")
        windowManager.saveWindowStatesOnQuit()
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
            isSettingsWindow(window)
        else { return }

        let hasOpenSettingsWindows: Bool = NSApp.windows.contains {
            isSettingsWindow($0) && $0 != window
        }
        if !hasOpenSettingsWindows {
            NSApp.setActivationPolicy(.accessory)
            logger.debug("Last settings window closing, hiding Dock icon")
        }
    }

    private func isSettingsWindow(_ window: NSWindow) -> Bool {
        window.styleMask.rawValue == 32771
    }
}
