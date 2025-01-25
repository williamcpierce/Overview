/*
 Settings/SettingsMigrationUtility.swift
 Overview

 Created by William Pierce on 1/24/25.

 Manages migration of user settings between bundle identifiers during app updates,
 preserving user preferences when transitioning from Overview to Overview-alpha.
*/

import Foundation

struct SettingsMigrationUtility {
    // Constants
    private static let prefixesToFilter: Set<String> = Set([
        "NS",
        "com.apple",
        "Apple",
    ])
    private static let oldBundleId = "WilliamPierce.Overview"
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

        HotkeySettingsKeys.bindings,

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

        guard let oldDefaults = UserDefaults(suiteName: oldBundleId) else {
            logger.warning("Migration skipped: cannot access old settings")
            return
        }

        migrateSettings(from: oldDefaults, to: newDefaults)
    }

    // MARK: - Private Methods

    private static func hasExistingSettings(in defaults: UserDefaults) -> Bool {
        Set(defaults.dictionaryRepresentation().keys)
            .intersection(settingsToMigrate)
            .isEmpty == false
    }

    private static func migrateSettings(
        from oldDefaults: UserDefaults, to newDefaults: UserDefaults
    ) {
        guard let oldDomain: [String : Any] = oldDefaults.persistentDomain(forName: oldBundleId),
            !oldDomain.isEmpty
        else {
            logger.debug("Migration skipped: no settings in old location")
            return
        }

        let migratedSettings: [String: Any] = filterSystemSettings(from: oldDomain)
        migrateIndividualSettings(migratedSettings, to: newDefaults)

        logMigrationResults(migratedSettings)
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

    private static func logMigrationResults(_ settings: [String: Any]) {
        let migratedKeys = settings.keys
            .filter { settingsToMigrate.contains($0) }
            .sorted()

        if migratedKeys.isEmpty {
            logger.info("No valid settings found to migrate")
            return
        }

        logger.info("Migrated \(migratedKeys.count) settings successfully")
        logger.debug("Settings migrated: \(migratedKeys.joined(separator: ", "))")
    }
}
