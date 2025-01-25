/*
 Settings/SettingsMigrationUtility.swift
 Overview

 Created by William Pierce on 1/24/25.

 Handles migration of user settings when bundle identifier changes, ensuring
 preferences are preserved when users update from Overview to Overview-alpha.
*/

import Foundation

/// Manages the migration of user settings between bundle identifiers during app updates
struct SettingsMigrationUtility {
    // MARK: - Constants
    private static let oldBundleId = "WilliamPierce.Overview"
    private static let newBundleId = "WilliamPierce.Overview-alpha"
    
    // MARK: - Dependencies
    private static let logger = AppLogger.settings
    
    // MARK: - Public Methods
    
    static func migrateSettingsIfNeeded() {
        let standardDefaults = UserDefaults.standard
        
        if hasExistingSettings(in: standardDefaults) {
            logger.debug("Settings exist in new location, skipping migration")
            return
        }
        
        guard let oldSettings = loadOldSettings() else {
            logger.debug("No settings found in old location")
            return
        }
        
        migrateSettings(oldSettings, to: standardDefaults)
    }
    
    // MARK: - Private Methods
    
    private static func hasExistingSettings(in defaults: UserDefaults) -> Bool {
        defaults.dictionaryRepresentation().keys.contains { key in
            [
                "windowOpacity",
                "frameRate",
                "focusBorderEnabled",
                "sourceTitleEnabled",
                "hotkeyBindings"
            ].contains(key)
        }
    }
    
    private static func loadOldSettings() -> [String: Any]? {
        guard let prefsDirectory = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first else {
            logger.warning("Could not locate preferences directory")
            return nil
        }
        
        let oldPrefsPath = "\(prefsDirectory)/Preferences/\(oldBundleId).plist"
        
        guard FileManager.default.fileExists(atPath: oldPrefsPath),
              let oldSettings = NSDictionary(contentsOfFile: oldPrefsPath) as? [String: Any],
              !oldSettings.isEmpty else {
            return nil
        }
        
        return oldSettings
    }
    
    private static func migrateSettings(_ settings: [String: Any], to defaults: UserDefaults) {
        let migratedSettings = settings.filter { key, _ in
            !key.hasPrefix("NS") &&      // Skip system UI state
            !key.hasPrefix("com.apple") && // Skip Apple-specific settings
            !key.hasPrefix("Apple")      // Skip Apple-specific settings
        }
        
        for (key, value) in migratedSettings {
            defaults.set(value, forKey: key)
        }
        
        defaults.synchronize()
        logger.info("Successfully migrated \(migratedSettings.count) settings")
        logger.debug("Migrated settings: \(migratedSettings.keys.joined(separator: ", "))")
    }
}
