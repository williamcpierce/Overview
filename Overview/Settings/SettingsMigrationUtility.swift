/*
 Settings/SettingsMigrationUtility.swift
 Overview

 Created by William Pierce on 1/24/25.

 Manages migration of user settings between bundle identifiers during app updates,
 preserving user preferences when transitioning from Overview and Overview-alpha.
*/

import Foundation

struct SettingsMigrationUtility {
    // Constants
    private static let prefixesToFilter: Set<String> = Set([
        "NS",
        "com.apple",
        "Apple",
    ])
    private static let oldBundleIds: [String] = [
        "WilliamPierce.Overview-alpha",
        "WilliamPierce.Overview",
    ]
    private static let settingsToMigrate = Set([
        PreviewSettingsKeys.captureFrameRate,
        PreviewSettingsKeys.hideInactiveApplications,
        PreviewSettingsKeys.hideActiveWindow,

        WindowSettingsKeys.previewOpacity,
        WindowSettingsKeys.defaultWidth,
        WindowSettingsKeys.defaultHeight,
        WindowSettingsKeys.managedByMissionControl,
        WindowSettingsKeys.shadowEnabled,
        WindowSettingsKeys.createOnLaunch,
        WindowSettingsKeys.closeOnCaptureStop,

        OverlaySettingsKeys.focusBorderEnabled,
        OverlaySettingsKeys.focusBorderWidth,
        OverlaySettingsKeys.focusBorderColor,
        OverlaySettingsKeys.sourceTitleEnabled,
        OverlaySettingsKeys.sourceTitleFontSize,
        OverlaySettingsKeys.sourceTitleBackgroundOpacity,
        OverlaySettingsKeys.sourceTitleLocation,
        OverlaySettingsKeys.sourceTitleType,

        SourceSettingsKeys.appNames,
        SourceSettingsKeys.filterMode,
    ])

    // Dependencies
    private static let logger = AppLogger.settings

    // MARK: - Public Methods

    static func migrateSettingsIfNeeded() {
        logger.debug("Checking for settings to migrate")

        let newDefaults = UserDefaults.standard
        guard !hasExistingSettings(in: newDefaults) else {
            logger.debug("Migration skipped: settings exist in new location")
            return
        }

        // Try each old bundle ID in order until we find one with settings
        for bundleId: String in oldBundleIds {
            if tryMigrateSettings(from: bundleId, to: newDefaults) {
                break
            }
        }
    }

    // MARK: - Private Methods

    private static func hasExistingSettings(in defaults: UserDefaults) -> Bool {
        Set(defaults.dictionaryRepresentation().keys)
            .intersection(settingsToMigrate)
            .isEmpty == false
    }

    private static func tryMigrateSettings(from bundleId: String, to newDefaults: UserDefaults)
        -> Bool
    {
        guard let oldDefaults = UserDefaults(suiteName: bundleId) else {
            logger.warning("Cannot access old settings for bundle: \(bundleId)")
            return false
        }

        guard let oldDomain: [String: Any] = oldDefaults.persistentDomain(forName: bundleId),
            !oldDomain.isEmpty
        else {
            logger.debug("No settings found in bundle: \(bundleId)")
            return false
        }

        let migratedSettings: [String: Any] = filterSystemSettings(from: oldDomain)
        migrateIndividualSettings(migratedSettings, to: newDefaults)

        logMigrationResults(migratedSettings, from: bundleId)
        return true
    }

    private static func filterSystemSettings(from settings: [String: Any]) -> [String: Any] {
        settings.filter { key, _ in
            prefixesToFilter.allSatisfy { prefix in
                !key.hasPrefix(prefix)
            }
        }
    }

    private static func migrateIndividualSettings(
        _ settings: [String: Any], to defaults: UserDefaults
    ) {
        for (key, value) in settings {
            defaults.set(value, forKey: key)
        }
        defaults.synchronize()
    }

    private static func logMigrationResults(_ settings: [String: Any], from bundleId: String) {
        let migratedKeys = settings.keys
            .filter { settingsToMigrate.contains($0) }
            .sorted()

        if migratedKeys.isEmpty {
            logger.info("No valid settings found to migrate from \(bundleId)")
            return
        }

        logger.info("Migrated \(migratedKeys.count) settings from \(bundleId)")
        logger.debug("Settings migrated: \(migratedKeys.joined(separator: ", "))")
    }
}
