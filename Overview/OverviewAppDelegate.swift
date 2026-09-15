/*
 OverviewAppDelegate.swift
 Overview

 Created by William Pierce on 9/15/24.

 The application delegate managing global state coordination and window management.
*/

import SwiftUI

@MainActor
final class OverviewAppDelegate: NSObject, NSApplicationDelegate {
    // Dependencies
    let logger = AppLogger.interface
    let permissionManager: PermissionManager
    let layoutManager: LayoutManager!
    let settingsManager: SettingsManager
    let sourceManager: SourceManager
    let previewManager: PreviewManager
    let shortcutManager: ShortcutManager
    var windowManager: WindowManager!

    override init() {
        permissionManager = PermissionManager()
        layoutManager = LayoutManager()

        sourceManager = SourceManager(
            permissionManager: permissionManager
        )
        previewManager = PreviewManager(
            sourceManager: sourceManager,
            permissionManager: permissionManager
        )
        shortcutManager = ShortcutManager(
            sourceManager: sourceManager,
            previewManager: previewManager
        )
        settingsManager = SettingsManager(
            layoutManager: layoutManager,
            shortcutManager: shortcutManager
        )

        super.init()

        windowManager = WindowManager(
            previewManager: previewManager,
            sourceManager: sourceManager,
            permissionManager: permissionManager,
            layoutManager: layoutManager
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

        permissionManager.updatePermissionStatus()
        windowManager.handleWindowsOnLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.debug("Application preparing to terminate")
        windowManager.handleWindowsOnQuit()
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
