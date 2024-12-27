/*
 Settings/AppSettings.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages application preferences and settings persistence, providing real-time updates
 across the application through Combine publishers and UserDefaults storage.
*/

import SwiftUI

class AppSettings: ObservableObject {
    // MARK: Window Appearance

    @Published var opacity: Double {
        didSet {
            let validatedValue = max(0.05, min(1.0, opacity))
            UserDefaults.standard.set(validatedValue, forKey: StorageKeys.opacity)
            AppLogger.settings.info("Window opacity updated to \(Int(validatedValue * 100))%")
        }
    }

    @Published var frameRate: Double {
        didSet {
            UserDefaults.standard.set(frameRate, forKey: StorageKeys.frameRate)
            AppLogger.settings.info("Frame rate updated to \(Int(frameRate)) FPS")
        }
    }

    // MARK: Window Dimensions

    @Published var defaultWindowWidth: Double {
        didSet {
            UserDefaults.standard.set(defaultWindowWidth, forKey: StorageKeys.defaultWidth)
            AppLogger.settings.info("Default window width set to \(Int(defaultWindowWidth))px")
        }
    }

    @Published var defaultWindowHeight: Double {
        didSet {
            UserDefaults.standard.set(defaultWindowHeight, forKey: StorageKeys.defaultHeight)
            AppLogger.settings.info("Default window height set to \(Int(defaultWindowHeight))px")
        }
    }

    // MARK: Visual Indicators

    @Published var showFocusedBorder: Bool {
        didSet {
            UserDefaults.standard.set(showFocusedBorder, forKey: StorageKeys.showBorder)
            AppLogger.settings.info("Focus border visibility set to \(showFocusedBorder)")
        }
    }

    @Published var focusBorderWidth: Double {
        didSet {
            UserDefaults.standard.set(focusBorderWidth, forKey: StorageKeys.borderWidth)
            AppLogger.settings.info("Focus border width set to \(focusBorderWidth)pt")
        }
    }

    @Published var focusBorderColor: Color {
        didSet {
            AppLogger.settings.info("Focus border color updated")
        }
    }

    @Published var showWindowTitle: Bool {
        didSet {
            UserDefaults.standard.set(showWindowTitle, forKey: StorageKeys.showTitle)
            AppLogger.settings.info("Window title visibility set to \(showWindowTitle)")
        }
    }

    @Published var titleFontSize: Double {
        didSet {
            UserDefaults.standard.set(titleFontSize, forKey: StorageKeys.titleSize)
            AppLogger.settings.info("Title font size set to \(titleFontSize)pt")
        }
    }

    @Published var titleBackgroundOpacity: Double {
        didSet {
            UserDefaults.standard.set(titleBackgroundOpacity, forKey: StorageKeys.titleOpacity)
            AppLogger.settings.info(
                "Title background opacity set to \(Int(titleBackgroundOpacity * 100))%")
        }
    }

    // MARK: System Integration

    @Published var managedByMissionControl: Bool {
        didSet {
            UserDefaults.standard.set(managedByMissionControl, forKey: StorageKeys.missionControl)
            AppLogger.settings.info("Mission Control integration set to \(managedByMissionControl)")
        }
    }

    @Published var enableEditModeAlignment: Bool {
        didSet {
            UserDefaults.standard.set(enableEditModeAlignment, forKey: StorageKeys.editAlignment)
            AppLogger.settings.info("Edit mode alignment set to \(enableEditModeAlignment)")
        }
    }

    @Published var hotkeyBindings: [HotkeyBinding] {
        didSet {
            if let encoded = try? JSONEncoder().encode(hotkeyBindings) {
                UserDefaults.standard.set(encoded, forKey: StorageKeys.hotkeys)
                guard !isInitializing else { return }

                do {
                    try HotkeyService.shared.registerHotkeys(hotkeyBindings)
                } catch {
                    AppLogger.settings.error(
                        "Failed to register hotkeys: \(error.localizedDescription)")
                }
            }
        }
    }

    private let logger = AppLogger.settings
    private var isInitializing: Bool = true

    init() {
        // Initialize with default values to ensure didSet triggers
        self.opacity = 0.95
        self.frameRate = 30.0
        self.defaultWindowWidth = 288
        self.defaultWindowHeight = 162
        self.showFocusedBorder = false
        self.focusBorderWidth = 5.0
        self.focusBorderColor = .gray
        self.showWindowTitle = false
        self.titleFontSize = 12.0
        self.titleBackgroundOpacity = 0.4
        self.managedByMissionControl = false
        self.enableEditModeAlignment = false
        self.hotkeyBindings = []

        logger.debug("Initializing settings")
        initializeFromDefaults()
        loadHotkeyBindings()
        validateAllSettings()
        isInitializing = false
        logger.debug("Settings initialization complete")
    }

    var defaultWindowSize: CGSize {
        CGSize(width: defaultWindowWidth, height: defaultWindowHeight)
    }

    func resetToDefaults() {
        logger.info("Resetting to default settings")

        let domain = Bundle.main.bundleIdentifier ?? "Overview"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        applyDefaultSettings()
        clearHotkeyBindings()

        logger.info("Settings reset completed")
    }

    private func initializeFromDefaults() {
        opacity = UserDefaults.standard.double(forKey: StorageKeys.opacity)
        frameRate = UserDefaults.standard.double(forKey: StorageKeys.frameRate)
        defaultWindowWidth = UserDefaults.standard.double(forKey: StorageKeys.defaultWidth)
        defaultWindowHeight = UserDefaults.standard.double(forKey: StorageKeys.defaultHeight)
        focusBorderWidth = UserDefaults.standard.double(forKey: StorageKeys.borderWidth)
        titleFontSize = UserDefaults.standard.double(forKey: StorageKeys.titleSize)
        titleBackgroundOpacity = UserDefaults.standard.double(forKey: StorageKeys.titleOpacity)
        showFocusedBorder = UserDefaults.standard.bool(forKey: StorageKeys.showBorder)
        showWindowTitle = UserDefaults.standard.bool(forKey: StorageKeys.showTitle)
        managedByMissionControl = UserDefaults.standard.bool(forKey: StorageKeys.missionControl)
        enableEditModeAlignment = UserDefaults.standard.bool(forKey: StorageKeys.editAlignment)
    }

    private func applyDefaultSettings() {
        opacity = 0.95
        frameRate = 30.0
        defaultWindowWidth = 288
        defaultWindowHeight = 162
        showFocusedBorder = false
        showWindowTitle = false
        managedByMissionControl = false
        enableEditModeAlignment = false
        focusBorderWidth = 5.0
        focusBorderColor = .gray
        titleFontSize = 12.0
        titleBackgroundOpacity = 0.4
    }

    private func loadHotkeyBindings() {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.hotkeys),
            let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data)
        else { return }

        hotkeyBindings = decoded
        logger.info("Loaded \(decoded.count) saved hotkey bindings")

        do {
            try HotkeyService.shared.registerHotkeys(hotkeyBindings)
        } catch {
            logger.error(
                "Failed to register hotkeys: \(error.localizedDescription)")
        }
    }

    private func clearHotkeyBindings() {
        hotkeyBindings = []
        do {
            try HotkeyService.shared.registerHotkeys(hotkeyBindings)
            logger.info("Cleared all hotkey bindings")
        } catch {
            logger.error("Failed to clear hotkeys: \(error.localizedDescription)")
        }
    }

    private func validateAllSettings() {
        validateOpacity()
        validateFrameRate()
        validateWindowDimensions()
        validateBorderWidth()
        validateTitleSettings()
    }

    private func validateOpacity() {
        guard opacity < 0.05 || opacity > 1.0 else { return }
        opacity = max(0.05, min(1.0, opacity))
    }

    private func validateFrameRate() {
        let validRates = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]
        guard !validRates.contains(frameRate) else { return }
        frameRate = 30.0
    }

    private func validateWindowDimensions() {
        if defaultWindowWidth < 100 { defaultWindowWidth = 288 }
        if defaultWindowHeight < 100 { defaultWindowHeight = 162 }
    }

    private func validateBorderWidth() {
        guard focusBorderWidth <= 0 else { return }
        focusBorderWidth = 5.0
    }

    private func validateTitleSettings() {
        if titleFontSize <= 0 { titleFontSize = 12.0 }
        if titleBackgroundOpacity < 0.0 || titleBackgroundOpacity > 1.0 {
            titleBackgroundOpacity = max(0.0, min(1.0, titleBackgroundOpacity))
        }
    }
}

private enum StorageKeys {
    static let opacity = "windowOpacity"
    static let frameRate = "frameRate"
    static let defaultWidth = "defaultWindowWidth"
    static let defaultHeight = "defaultWindowHeight"
    static let showBorder = "showFocusedBorder"
    static let borderWidth = "focusBorderWidth"
    static let showTitle = "showWindowTitle"
    static let titleSize = "titleFontSize"
    static let titleOpacity = "titleBackgroundOpacity"
    static let missionControl = "managedByMissionControl"
    static let editAlignment = "enableEditModeAlignment"
    static let hotkeys = "hotkeyBindings"
}
