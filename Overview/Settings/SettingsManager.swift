/*
 Settings/SettingsManager.swift
 Overview

 Created by William Pierce on 1/12/25.

 Manages centralized settings operations and reset functionality across the application.
*/

import Defaults
import Sparkle
import SwiftUI

@MainActor
final class SettingsManager: ObservableObject {
    // Dependencies
    private let updateManager: UpdateManager
    private let layoutManager: LayoutManager
    private let shortcutManager: ShortcutManager
    private let logger = AppLogger.settings

    init(
        updateManager: UpdateManager, layoutManager: LayoutManager, shortcutManager: ShortcutManager
    ) {
        self.updateManager = updateManager
        self.layoutManager = layoutManager
        self.shortcutManager = shortcutManager
    }

    // MARK: - Settings Reset

    func resetAllSettings() {
        logger.info("Initiating settings reset")

        /// Reset Shortcut settings
        shortcutManager.shortcutStorage.resetToDefaults()

        /// Reset Window settings
        Defaults.reset(
            .windowOpacity,
            .defaultWindowWidth,
            .defaultWindowHeight,
            .windowShadowEnabled,
            .syncAspectRatio,
            .managedByMissionControl,
            .createOnLaunch,
            .closeOnCaptureStop,
            .assignPreviewsToAllDesktops,
            .saveWindowsOnQuit,
            .restoreWindowsOnLaunch
        )

        /// Reset Overlay settings
        Defaults.reset(
            .focusBorderEnabled,
            .focusBorderWidth,
            .focusBorderColor,
            .sourceTitleEnabled,
            .sourceTitleFontSize,
            .sourceTitleBackgroundOpacity,
            .sourceTitleLocation,
            .sourceTitleType
        )

        /// Reset Layout settings
        Defaults.reset(
            .layouts,
            .launchLayoutId,
            .closeWindowsOnApply
        )
        layoutManager.layouts = []
        layoutManager.setLaunchLayout(id: nil)

        /// Reset Preview settings
        Defaults.reset(
            .captureFrameRate,
            .hideInactiveApplications,
            .hideActiveWindow
        )

        /// Reset Update settings
        updateManager.updater.automaticallyChecksForUpdates = true
        updateManager.updater.automaticallyDownloadsUpdates = false
        Defaults.reset(.enableBetaUpdates)

        /// Reset Source settings
        Defaults.reset(
            .filterMode,
            .appFilterNames
        )

        logger.info("Settings reset completed successfully")
    }
}
