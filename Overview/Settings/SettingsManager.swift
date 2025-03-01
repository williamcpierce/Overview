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

    // Services
    let diagnosticService: DiagnosticService

    init(
        updateManager: UpdateManager, layoutManager: LayoutManager, shortcutManager: ShortcutManager
    ) {
        self.updateManager = updateManager
        self.layoutManager = layoutManager
        self.shortcutManager = shortcutManager
        self.diagnosticService = DiagnosticService(shortcutManager: shortcutManager)
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
            .storedLayouts,
            .launchLayoutUUID,
            .closeWindowsOnApply
        )
        layoutManager.resetToDefaults()

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

    // MARK: - Diagnostic Functions

    func generateDiagnosticReport() async throws -> String {
        return try await diagnosticService.generateDiagnosticReport()
    }

    func saveDiagnosticReport(_ report: String) async throws -> URL {
        return try await diagnosticService.saveDiagnosticReport(report)
    }
}
