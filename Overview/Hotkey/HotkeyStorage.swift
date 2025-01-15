/*
 Hotkey/Settings/HotkeyStorage.swift
 Overview

 Created by William Pierce on 1/12/24.
*/

import SwiftUI

class HotkeyStorage: ObservableObject {
    // Dependencies
    private let logger = AppLogger.settings

    // Private State
    private var isInitializing: Bool = true

    // Singleton
    private let hotkeyService = HotkeyService.shared

    // Published State
    @Published var hotkeyBindings: [HotkeyBinding] {
        didSet {
            guard !isInitializing,
                let encoded = try? JSONEncoder().encode(hotkeyBindings)
            else { return }

            UserDefaults.standard.set(encoded, forKey: HotkeySettingsKeys.bindings)

            do {
                try hotkeyService.registerHotkeys(hotkeyBindings)
            } catch {
                logger.logError(error, context: "Failed to register hotkeys")
            }
        }
    }

    init() {
        logger.debug("Initializing settings manager")
        self.hotkeyBindings = HotkeySettingsKeys.defaults.bindings

        loadHotkeyBindings()

        isInitializing = false
        logger.debug("Settings manager initialization complete")
    }

    // MARK: - Public Methods

    func resetToDefaults() {
        logger.debug("Initiating hotkey settings reset")

        hotkeyBindings = HotkeySettingsKeys.defaults.bindings

        clearHotkeyBindings()
        logger.info("Hotkey settings reset completed successfully")
    }

    // MARK: - Private Methods

    private func loadHotkeyBindings() {
        logger.debug("Loading hotkey bindings from storage")

        guard let data = UserDefaults.standard.data(forKey: HotkeySettingsKeys.bindings),
            let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data)
        else { return }

        hotkeyBindings = decoded
        logger.debug("Loaded \(decoded.count) saved hotkey bindings")

        do {
            try hotkeyService.registerHotkeys(hotkeyBindings)
        } catch {
            logger.logError(error, context: "Failed to register hotkeys")
        }
    }

    private func clearHotkeyBindings() {
        logger.debug("Clearing all hotkey bindings")

        hotkeyBindings = HotkeySettingsKeys.defaults.bindings
        do {
            try hotkeyService.registerHotkeys(hotkeyBindings)
            logger.info("Successfully cleared all hotkey bindings")
        } catch {
            logger.logError(error, context: "Failed to clear hotkeys")
        }
    }
}
