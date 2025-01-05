/*
 Settings/AppSettings.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages application-wide settings and preferences, handling persistence,
 validation, and real-time updates for UI configuration and capture behavior.
*/

import SwiftUI

/// Centralizes application settings management with SwiftUI property wrapper support
/// and automatic persistence to UserDefaults.
class AppSettings: ObservableObject {
    // MARK: - Private State
    private var isInitializing: Bool = true

    // MARK: - Dependancies
    private let logger = AppLogger.settings
    private let hotkeyService = HotkeyService.shared
    
    // MARK: - Constants
    let availableFrameRates: [Double] = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]
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
        static let closeOnCaptureStop: Bool = false
        static let hideInactiveApplications: Bool = false
        static let hideActiveWindow: Bool = false
        static let enableEditModeAlignment: Bool = false
        static let hotkeyBindings: [HotkeyBinding] = []
        static let appFilterNames: [String] = []
        static let isFilterBlocklist: Bool = true
    }

    // MARK: - Window Appearance Settings

    @Published var windowOpacity: Double {
        didSet {
            UserDefaults.standard.set(windowOpacity, forKey: StorageKeys.windowOpacity)
            logger.info("Window opacity updated to \(Int(windowOpacity * 100))%")
        }
    }

    // MARK: - Performance Settings

    @Published var frameRate: Double {
        didSet {
            UserDefaults.standard.set(frameRate, forKey: StorageKeys.frameRate)
            logger.info("Frame rate updated to \(Int(frameRate)) FPS")
        }
    }

    // MARK: - Window Dimension Settings

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

    // MARK: - Focus Border Settings

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

    // MARK: - Title Overlay Settings

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
                titleBackgroundOpacity,
                forKey: StorageKeys.titleBackgroundOpacity
            )
            logger.info("Title background opacity set to \(Int(titleBackgroundOpacity * 100))%")
        }
    }

    // MARK: - Window Behavior Settings

    @Published var managedByMissionControl: Bool {
        didSet {
            UserDefaults.standard.set(
                managedByMissionControl,
                forKey: StorageKeys.managedByMissionControl
            )
            logger.info("Mission Control integration set to \(managedByMissionControl)")
        }
    }

    @Published var closeOnCaptureStop: Bool {
        didSet {
            UserDefaults.standard.set(closeOnCaptureStop, forKey: StorageKeys.closeOnCaptureStop)
            logger.info("Close on capture stop set to \(closeOnCaptureStop)")
        }
    }

    @Published var hideInactiveApplications: Bool {
        didSet {
            UserDefaults.standard.set(
                hideInactiveApplications,
                forKey: StorageKeys.hideInactiveApplications
            )
            logger.info("Hide inactive applications set to \(hideInactiveApplications)")
        }
    }

    @Published var hideActiveWindow: Bool {
        didSet {
            UserDefaults.standard.set(hideActiveWindow, forKey: StorageKeys.hideActiveWindow)
            logger.info("Hide active window set to \(hideActiveWindow)")
        }
    }

    @Published var enableEditModeAlignment: Bool {
        didSet {
            UserDefaults.standard.set(
                enableEditModeAlignment,
                forKey: StorageKeys.enableEditModeAlignment
            )
            logger.info("Edit mode alignment set to \(enableEditModeAlignment)")
        }
    }

    // MARK: - Hotkey Settings

    @Published var hotkeyBindings: [HotkeyBinding] {
        didSet {
            guard !isInitializing,
                let encoded = try? JSONEncoder().encode(hotkeyBindings)
            else { return }

            UserDefaults.standard.set(encoded, forKey: StorageKeys.hotkeyBindings)

            do {
                try hotkeyService.registerHotkeys(hotkeyBindings)
            } catch {
                logger.logError(error, context: "Failed to register hotkeys")
            }
        }
    }

    // MARK: - Filter Settings

    @Published var appFilterNames: [String] {
        didSet {
            UserDefaults.standard.set(appFilterNames, forKey: StorageKeys.appFilterNames)
            logger.info("App filter names updated: count=\(appFilterNames.count)")
        }
    }

    @Published var isFilterBlocklist: Bool {
        didSet {
            UserDefaults.standard.set(isFilterBlocklist, forKey: StorageKeys.isFilterBlocklist)
            logger.info("Filter mode updated: isBlocklist=\(isFilterBlocklist)")
        }
    }

    // MARK: - Initialization

    init() {
        logger.debug("Initializing settings manager")

        // Initialize with default values
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
        self.closeOnCaptureStop = Defaults.closeOnCaptureStop
        self.hideInactiveApplications = Defaults.hideInactiveApplications
        self.hideActiveWindow = Defaults.hideActiveWindow
        self.enableEditModeAlignment = Defaults.enableEditModeAlignment
        self.hotkeyBindings = Defaults.hotkeyBindings
        self.appFilterNames = Defaults.appFilterNames
        self.isFilterBlocklist = Defaults.isFilterBlocklist

        initializeFromStorage()
        loadHotkeyBindings()
        validateSettings()

        isInitializing = false
        logger.info("Settings manager initialization complete")
    }

    // MARK: - Public Methods

    /// Resets all settings to their default values and clears persisted data
    func resetToDefaults() {
        logger.info("Initiating settings reset")

        let domain = Bundle.main.bundleIdentifier ?? "Overview"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        // Reset all properties to defaults
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
        managedByMissionControl = Defaults.managedByMissionControl
        closeOnCaptureStop = Defaults.closeOnCaptureStop
        hideInactiveApplications = Defaults.hideInactiveApplications
        hideActiveWindow = Defaults.hideActiveWindow
        enableEditModeAlignment = Defaults.enableEditModeAlignment
        appFilterNames = Defaults.appFilterNames
        isFilterBlocklist = Defaults.isFilterBlocklist

        clearHotkeyBindings()
        logger.info("Settings reset completed successfully")
    }

    // MARK: - Private Methods

    private func initializeFromStorage() {
        logger.debug("Loading settings from storage")

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
        closeOnCaptureStop = UserDefaults.standard.bool(
            forKey: StorageKeys.closeOnCaptureStop)
        hideInactiveApplications = UserDefaults.standard.bool(
            forKey: StorageKeys.hideInactiveApplications)
        hideActiveWindow = UserDefaults.standard.bool(
            forKey: StorageKeys.hideActiveWindow)
        enableEditModeAlignment = UserDefaults.standard.bool(
            forKey: StorageKeys.enableEditModeAlignment)
        appFilterNames =
            UserDefaults.standard.array(
                forKey: StorageKeys.appFilterNames) as? [String] ?? []
        isFilterBlocklist = UserDefaults.standard.bool(
            forKey: StorageKeys.isFilterBlocklist)
    }

    private func loadHotkeyBindings() {
        logger.debug("Loading hotkey bindings from storage")

        guard let data = UserDefaults.standard.data(forKey: StorageKeys.hotkeyBindings),
            let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data)
        else { return }

        hotkeyBindings = decoded
        logger.info("Loaded \(decoded.count) saved hotkey bindings")

        do {
            try hotkeyService.registerHotkeys(hotkeyBindings)
        } catch {
            logger.logError(error, context: "Failed to register hotkeys")
        }
    }

    private func clearHotkeyBindings() {
        logger.debug("Clearing all hotkey bindings")

        hotkeyBindings = Defaults.hotkeyBindings
        do {
            try hotkeyService.registerHotkeys(hotkeyBindings)
            logger.info("Successfully cleared all hotkey bindings")
        } catch {
            logger.logError(error, context: "Failed to clear hotkeys")
        }
    }

    private func validateSettings() {
        logger.debug("Starting settings validation")

        validateOpacity()
        validateFrameRate()
        validateWindowDimensions()
        validateBorderWidth()
        validateTitleSettings()

        logger.debug("Settings validation complete")
    }

    private func validateOpacity() {
        guard windowOpacity < 0.05 || windowOpacity > 1.0 else { return }
        logger.warning("Invalid opacity value (\(windowOpacity)), resetting to default")
        windowOpacity = Defaults.windowOpacity
    }

    private func validateFrameRate() {
        guard !availableFrameRates.contains(frameRate) else { return }
        logger.warning("Invalid frame rate (\(frameRate)), resetting to default")
        frameRate = Defaults.frameRate
    }

    private func validateWindowDimensions() {
        if defaultWindowWidth < 100 {
            logger.warning("Invalid window width (\(defaultWindowWidth)), resetting to default")
            defaultWindowWidth = Defaults.defaultWindowWidth
        }
        if defaultWindowHeight < 100 {
            logger.warning("Invalid window height (\(defaultWindowHeight)), resetting to default")
            defaultWindowHeight = Defaults.defaultWindowHeight
        }
    }

    private func validateBorderWidth() {
        guard focusBorderWidth <= 0 else { return }
        logger.warning("Invalid border width (\(focusBorderWidth)), resetting to default")
        focusBorderWidth = Defaults.focusBorderWidth
    }

    private func validateTitleSettings() {
        if titleFontSize <= 0 {
            logger.warning("Invalid title font size (\(titleFontSize)), resetting to default")
            titleFontSize = Defaults.titleFontSize
        }
        if titleBackgroundOpacity < 0.0 || titleBackgroundOpacity > 1.0 {
            logger.warning(
                "Invalid title background opacity (\(titleBackgroundOpacity)), resetting to default"
            )
            titleBackgroundOpacity = Defaults.titleBackgroundOpacity
        }
    }
}

// MARK: - Storage Keys

/// Defines keys for persisting settings in UserDefaults
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
    static let closeOnCaptureStop: String = "closeOnCaptureStop"
    static let hideInactiveApplications: String = "hideInactiveApplications"
    static let hideActiveWindow: String = "hideActiveWindow"
    static let enableEditModeAlignment: String = "enableEditModeAlignment"
    static let hotkeyBindings: String = "hotkeyBindings"
    static let appFilterNames: String = "appFilterNames"
    static let isFilterBlocklist: String = "isFilterBlocklist"
}
