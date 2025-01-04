/*
 Settings/AppSettings.swift
 Overview

 Created by William Pierce on 10/13/24.
*/

import SwiftUI

class AppSettings: ObservableObject {
    let availableFrameRates: [Double] = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]
    private let hotkeyService = HotkeyService.shared
    private let logger = AppLogger.settings
    private var isInitializing: Bool = true

    // MARK: - Default Values

    private struct Defaults {
        static let windowOpacity: Double = 0.95
        static let frameRate: Double = 10.0
        static let defaultWindowWidth: Double = 288
        static let defaultWindowHeight: Double = 162
        static let showFocusedBorder: Bool = true
        static let focusBorderWidth: Double = 5.0
        static let focusBorderColor: Color = .gray
        static let showWindowTitle: Bool = true
        static let titleFontSize: Double = 12.0
        static let titleBackgroundOpacity: Double = 0.4
        static let managedByMissionControl: Bool = true
        static let hideInactiveApplications: Bool = false
        static let hideActiveWindow: Bool = false
        static let enableEditModeAlignment: Bool = false
        static let hotkeyBindings: [HotkeyBinding] = []
    }

    // MARK: - Window Appearance

    @Published var windowOpacity: Double {
        didSet {
            UserDefaults.standard.set(windowOpacity, forKey: StorageKeys.windowOpacity)
            logger.info("Window opacity updated to \(Int(windowOpacity * 100))%")
        }
    }

    // MARK: - Performance

    @Published var frameRate: Double {
        didSet {
            UserDefaults.standard.set(frameRate, forKey: StorageKeys.frameRate)
            logger.info("Frame rate updated to \(Int(frameRate)) FPS")
        }
    }

    // MARK: - Window Dimensions

    @Published var defaultWindowWidth: Double {
        didSet {
            UserDefaults.standard.set(defaultWindowWidth, forKey: StorageKeys.defaultWindowWidth)
            logger.info("Default window width set to \(Int(defaultWindowWidth))px")
        }
    }

    @Published var defaultWindowHeight: Double {
        didSet {
            UserDefaults.standard.set(defaultWindowHeight, forKey: StorageKeys.defaultWindowHeight)
            logger.info("Default window height set to \(Int(defaultWindowHeight))px")
        }
    }

    // MARK: - Focus Border Overlay

    @Published var showFocusedBorder: Bool {
        didSet {
            UserDefaults.standard.set(showFocusedBorder, forKey: StorageKeys.showFocusedBorder)
            logger.info("Focus border visibility set to \(showFocusedBorder)")
        }
    }

    @Published var focusBorderWidth: Double {
        didSet {
            UserDefaults.standard.set(focusBorderWidth, forKey: StorageKeys.focusBorderWidth)
            logger.info("Focus border width set to \(focusBorderWidth)pt")
        }
    }

    @Published var focusBorderColor: Color {
        didSet {
            UserDefaults.standard.setColor(focusBorderColor, forKey: StorageKeys.focusBorderColor)
            logger.info("Focus border color updated")
        }
    }

    // MARK: - Title Overlay

    @Published var showWindowTitle: Bool {
        didSet {
            UserDefaults.standard.set(showWindowTitle, forKey: StorageKeys.showWindowTitle)
            logger.info("Window title visibility set to \(showWindowTitle)")
        }
    }

    @Published var titleFontSize: Double {
        didSet {
            UserDefaults.standard.set(titleFontSize, forKey: StorageKeys.titleFontSize)
            logger.info("Title font size set to \(titleFontSize)pt")
        }
    }

    @Published var titleBackgroundOpacity: Double {
        didSet {
            UserDefaults.standard.set(
                titleBackgroundOpacity, forKey: StorageKeys.titleBackgroundOpacity)
            logger.info("Title background opacity set to \(Int(titleBackgroundOpacity * 100))%")
        }
    }

    // MARK: - Window Behavior

    @Published var managedByMissionControl: Bool {
        didSet {
            UserDefaults.standard.set(
                managedByMissionControl, forKey: StorageKeys.managedByMissionControl)
            logger.info("Mission Control integration set to \(managedByMissionControl)")
        }
    }

    @Published var hideInactiveApplications: Bool {
        didSet {
            UserDefaults.standard.set(
                hideInactiveApplications, forKey: StorageKeys.hideInactiveApplications)
            logger.info("Hide inactive applications set to \(hideInactiveApplications)")
        }
    }

    @Published var hideActiveWindow: Bool {
        didSet {
            UserDefaults.standard.set(
                hideActiveWindow, forKey: StorageKeys.hideActiveWindow)
            logger.info("Hide active window set to \(hideActiveWindow)")
        }
    }

    @Published var enableEditModeAlignment: Bool {
        didSet {
            UserDefaults.standard.set(
                enableEditModeAlignment, forKey: StorageKeys.enableEditModeAlignment)
            logger.info("Edit mode alignment set to \(enableEditModeAlignment)")
        }
    }

    // MARK: - Hotkeys

    @Published var hotkeyBindings: [HotkeyBinding] {
        didSet {
            guard !isInitializing,
                let encoded = try? JSONEncoder().encode(hotkeyBindings)
            else { return }

            UserDefaults.standard.set(encoded, forKey: StorageKeys.hotkeyBindings)

            do {
                try hotkeyService.registerHotkeys(hotkeyBindings)
            } catch {
                logger.error("Failed to register hotkeys: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Initialization

    init() {
        self.windowOpacity = Defaults.windowOpacity
        self.frameRate = Defaults.frameRate
        self.defaultWindowWidth = Defaults.defaultWindowWidth
        self.defaultWindowHeight = Defaults.defaultWindowHeight
        self.showFocusedBorder = Defaults.showFocusedBorder
        self.focusBorderWidth = Defaults.focusBorderWidth
        self.focusBorderColor = Defaults.focusBorderColor
        self.showWindowTitle = Defaults.showWindowTitle
        self.titleFontSize = Defaults.titleFontSize
        self.titleBackgroundOpacity = Defaults.titleBackgroundOpacity
        self.managedByMissionControl = Defaults.managedByMissionControl
        self.hideInactiveApplications = Defaults.hideInactiveApplications
        self.hideActiveWindow = Defaults.hideActiveWindow
        self.enableEditModeAlignment = Defaults.enableEditModeAlignment
        self.hotkeyBindings = Defaults.hotkeyBindings

        logger.debug("Initializing settings")
        initializeFromStorage()
        loadHotkeyBindings()
        validateSettings()
        isInitializing = false
        logger.debug("Settings initialization complete")
    }

    // MARK: - Public Methods

    func resetToDefaults() {
        logger.info("Resetting to default settings")

        let domain = Bundle.main.bundleIdentifier ?? "Overview"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        windowOpacity = Defaults.windowOpacity
        frameRate = Defaults.frameRate
        defaultWindowWidth = Defaults.defaultWindowWidth
        defaultWindowHeight = Defaults.defaultWindowHeight
        showFocusedBorder = Defaults.showFocusedBorder
        focusBorderWidth = Defaults.focusBorderWidth
        focusBorderColor = Defaults.focusBorderColor
        showWindowTitle = Defaults.showWindowTitle
        titleFontSize = Defaults.titleFontSize
        titleBackgroundOpacity = Defaults.titleBackgroundOpacity
        hideInactiveApplications = Defaults.hideInactiveApplications
        hideActiveWindow = Defaults.hideActiveWindow
        managedByMissionControl = Defaults.managedByMissionControl
        enableEditModeAlignment = Defaults.enableEditModeAlignment

        clearHotkeyBindings()
        logger.info("Settings reset completed")
    }

    // MARK: - Private Methods

    private func initializeFromStorage() {
        windowOpacity = UserDefaults.standard.double(forKey: StorageKeys.windowOpacity)
        frameRate = UserDefaults.standard.double(forKey: StorageKeys.frameRate)
        defaultWindowWidth = UserDefaults.standard.double(forKey: StorageKeys.defaultWindowWidth)
        defaultWindowHeight = UserDefaults.standard.double(forKey: StorageKeys.defaultWindowHeight)
        showFocusedBorder = UserDefaults.standard.bool(forKey: StorageKeys.showFocusedBorder)
        focusBorderWidth = UserDefaults.standard.double(forKey: StorageKeys.focusBorderWidth)
        focusBorderColor = UserDefaults.standard.color(forKey: StorageKeys.focusBorderColor)
        showWindowTitle = UserDefaults.standard.bool(forKey: StorageKeys.showWindowTitle)
        titleFontSize = UserDefaults.standard.double(forKey: StorageKeys.titleFontSize)
        titleBackgroundOpacity = UserDefaults.standard.double(
            forKey: StorageKeys.titleBackgroundOpacity)
        managedByMissionControl = UserDefaults.standard.bool(
            forKey: StorageKeys.managedByMissionControl)
        hideInactiveApplications = UserDefaults.standard.bool(
            forKey: StorageKeys.hideInactiveApplications)
        hideActiveWindow = UserDefaults.standard.bool(
            forKey: StorageKeys.hideActiveWindow)
        enableEditModeAlignment = UserDefaults.standard.bool(
            forKey: StorageKeys.enableEditModeAlignment)
    }

    private func loadHotkeyBindings() {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.hotkeyBindings),
            let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data)
        else { return }

        hotkeyBindings = decoded
        logger.info("Loaded \(decoded.count) saved hotkey bindings")

        do {
            try hotkeyService.registerHotkeys(hotkeyBindings)
        } catch {
            logger.error("Failed to register hotkeys: \(error.localizedDescription)")
        }
    }

    private func clearHotkeyBindings() {
        hotkeyBindings = Defaults.hotkeyBindings
        do {
            try hotkeyService.registerHotkeys(hotkeyBindings)
            logger.info("Cleared all hotkey bindings")
        } catch {
            logger.error("Failed to clear hotkeys: \(error.localizedDescription)")
        }
    }

    private func validateSettings() {
        validateOpacity()
        validateFrameRate()
        validateWindowDimensions()
        validateBorderWidth()
        validateTitleSettings()
    }

    private func validateOpacity() {
        guard windowOpacity < 0.05 || windowOpacity > 1.0 else { return }
        windowOpacity = Defaults.windowOpacity
    }

    private func validateFrameRate() {
        guard !availableFrameRates.contains(frameRate) else { return }
        frameRate = Defaults.frameRate
    }

    private func validateWindowDimensions() {
        if defaultWindowWidth < 100 { defaultWindowWidth = Defaults.defaultWindowWidth }
        if defaultWindowHeight < 100 { defaultWindowHeight = Defaults.defaultWindowHeight }
    }

    private func validateBorderWidth() {
        guard focusBorderWidth <= 0 else { return }
        focusBorderWidth = Defaults.focusBorderWidth
    }

    private func validateTitleSettings() {
        if titleFontSize <= 0 { titleFontSize = Defaults.titleFontSize }
        if titleBackgroundOpacity < 0.0 || titleBackgroundOpacity > 1.0 {
            titleBackgroundOpacity = Defaults.titleBackgroundOpacity
        }
    }
}

// MARK: - Storage Keys

private enum StorageKeys {
    static let windowOpacity: String = "windowOpacity"
    static let frameRate: String = "frameRate"
    static let defaultWindowWidth: String = "defaultWindowWidth"
    static let defaultWindowHeight: String = "defaultWindowHeight"
    static let showFocusedBorder: String = "showFocusedBorder"
    static let focusBorderWidth: String = "focusBorderWidth"
    static let focusBorderColor: String = "focusBorderColor"
    static let showWindowTitle: String = "showWindowTitle"
    static let titleFontSize: String = "titleFontSize"
    static let titleBackgroundOpacity: String = "titleBackgroundOpacity"
    static let managedByMissionControl: String = "managedByMissionControl"
    static let hideInactiveApplications: String = "hideInactiveApplications"
    static let hideActiveWindow: String = "hideActiveWindow"
    static let enableEditModeAlignment: String = "enableEditModeAlignment"
    static let hotkeyBindings: String = "hotkeyBindings"
}
