/*
 Settings/SettingsManager.swift
 Overview

 Created by William Pierce on 1/12/25.

 Manages centralized settings operations and reset functionality across the application.
*/

import Sparkle
import SwiftUI

@MainActor
final class SettingsManager: ObservableObject {
    // Dependencies
    private let updateManager: UpdateManager
    private let layoutManager: LayoutManager
    private let logger = AppLogger.settings

    // Published State
    @Published var filterAppNames: [String] {
        didSet {
            UserDefaults.standard.set(filterAppNames, forKey: SourceSettingsKeys.appNames)
        }
    }

    init(updateManager: UpdateManager, layoutManager: LayoutManager) {
        self.updateManager = updateManager
        self.layoutManager = layoutManager

        if let storedNames = UserDefaults.standard.array(forKey: SourceSettingsKeys.appNames)
            as? [String]
        {
            self.filterAppNames = storedNames
        } else {
            self.filterAppNames = SourceSettingsKeys.defaults.appNames
        }
    }

    // MARK: - Settings Reset

    func resetAllSettings() {
        logger.info("Initiating settings reset")

        /// Reset Keyboard Shortcut settings
        ShortcutStorage.shared.resetToDefaults()

        let domain: String = Bundle.main.bundleIdentifier ?? "Overview"
        UserDefaults.standard.removePersistentDomain(forName: domain)

        /// Reset Window settings
        UserDefaults.standard.set(
            WindowSettingsKeys.defaults.previewOpacity,
            forKey: WindowSettingsKeys.previewOpacity)
        UserDefaults.standard.set(
            WindowSettingsKeys.defaults.defaultWidth,
            forKey: WindowSettingsKeys.defaultWidth)
        UserDefaults.standard.set(
            WindowSettingsKeys.defaults.defaultHeight,
            forKey: WindowSettingsKeys.defaultHeight)
        UserDefaults.standard.set(
            WindowSettingsKeys.defaults.managedByMissionControl,
            forKey: WindowSettingsKeys.managedByMissionControl)
        UserDefaults.standard.set(
            WindowSettingsKeys.defaults.shadowEnabled,
            forKey: WindowSettingsKeys.shadowEnabled)
        UserDefaults.standard.set(
            WindowSettingsKeys.defaults.createOnLaunch,
            forKey: WindowSettingsKeys.createOnLaunch)
        UserDefaults.standard.set(
            WindowSettingsKeys.defaults.closeOnCaptureStop,
            forKey: WindowSettingsKeys.closeOnCaptureStop)
        UserDefaults.standard.set(
            WindowSettingsKeys.defaults.assignPreviewsToAllDesktops,
            forKey: WindowSettingsKeys.assignPreviewsToAllDesktops)
        UserDefaults.standard.set(
            WindowSettingsKeys.defaults.saveWindowsOnQuit,
            forKey: WindowSettingsKeys.saveWindowsOnQuit)

        /// Reset Overlay settings
        UserDefaults.standard.set(
            OverlaySettingsKeys.defaults.focusBorderEnabled,
            forKey: OverlaySettingsKeys.focusBorderEnabled)
        UserDefaults.standard.set(
            OverlaySettingsKeys.defaults.focusBorderWidth,
            forKey: OverlaySettingsKeys.focusBorderWidth)
        UserDefaults.standard.set(
            OverlaySettingsKeys.defaults.focusBorderColor.rawValue,
            forKey: OverlaySettingsKeys.focusBorderColor)
        UserDefaults.standard.set(
            OverlaySettingsKeys.defaults.sourceTitleEnabled,
            forKey: OverlaySettingsKeys.sourceTitleEnabled)
        UserDefaults.standard.set(
            OverlaySettingsKeys.defaults.sourceTitleFontSize,
            forKey: OverlaySettingsKeys.sourceTitleFontSize)
        UserDefaults.standard.set(
            OverlaySettingsKeys.defaults.sourceTitleBackgroundOpacity,
            forKey: OverlaySettingsKeys.sourceTitleBackgroundOpacity)
        UserDefaults.standard.set(
            OverlaySettingsKeys.defaults.sourceTitleLocation,
            forKey: OverlaySettingsKeys.sourceTitleLocation)
        UserDefaults.standard.set(
            OverlaySettingsKeys.defaults.sourceTitleType,
            forKey: OverlaySettingsKeys.sourceTitleType)

        /// Reset Layout settings
        UserDefaults.standard.removeObject(forKey: LayoutSettingsKeys.layouts)
        UserDefaults.standard.removeObject(forKey: LayoutSettingsKeys.launchLayoutId)
        UserDefaults.standard.set(
            LayoutSettingsKeys.defaults.applyLayoutOnLaunch,
            forKey: LayoutSettingsKeys.applyLayoutOnLaunch)
        layoutManager.layouts = []
        layoutManager.setLaunchLayout(id: nil)

        /// Reset Preview settings
        UserDefaults.standard.set(
            PreviewSettingsKeys.defaults.hideInactiveApplications,
            forKey: PreviewSettingsKeys.hideInactiveApplications)
        UserDefaults.standard.set(
            PreviewSettingsKeys.defaults.hideActiveWindow,
            forKey: PreviewSettingsKeys.hideActiveWindow)
        UserDefaults.standard.set(
            PreviewSettingsKeys.defaults.captureFrameRate,
            forKey: PreviewSettingsKeys.captureFrameRate)

        /// Reset Update settings
        updateManager.updater.automaticallyChecksForUpdates = true
        updateManager.updater.automaticallyDownloadsUpdates = false
        UserDefaults.standard.set(
            UpdateSettingsKeys.defaults.enableBetaUpdates,
            forKey: UpdateSettingsKeys.enableBetaUpdates)

        /// Reset Source settings
        filterAppNames = SourceSettingsKeys.defaults.appNames
        UserDefaults.standard.set(
            SourceSettingsKeys.defaults.filterMode,
            forKey: SourceSettingsKeys.filterMode)

        logger.info("Settings reset completed successfully")
    }
}
