/*
 Settings/AppSettings.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages application-wide settings and preferences, handling persistence,
 validation, and real-time updates for UI configuration and capture behavior.
*/

import SwiftUI

class AppSettings: ObservableObject {
    // MARK: - Dependancies
    private let logger = AppLogger.settings
    private let hotkeyService = HotkeyService.shared

    // MARK: - Private State
    private var isInitializing: Bool = true

    // MARK: - Constants
    let availableCaptureFrameRates: [Double] = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]
    private struct Defaults {
        static let focusBorderEnabled: Bool = true
        static let focusBorderWidth: Double = 5.0
        static let focusBorderColor: Color = .gray
        static let sourceTitleEnabled: Bool = true
        static let sourceTitleFontSize: Double = 12.0
        static let sourceTitleBackgroundOpacity: Double = 0.4
        static let previewOpacity: Double = 0.95
        static let previewCloseOnCaptureStop: Bool = false
        static let previewHideInactiveApplications: Bool = false
        static let previewHideActiveWindow: Bool = false
        static let windowDefaultWidth: Double = 288
        static let windowDefaultHeight: Double = 162
        static let windowManagedByMissionControl: Bool = true
        static let windowAlignmentEnabled: Bool = false
        static let windowShadowEnabled: Bool = false
        static let captureFrameRate: Double = 10.0
        static let hotkeyBindings: [HotkeyBinding] = []
        static let filterAppNames: [String] = []
        static let filterBlocklist: Bool = true
    }

    // MARK: - Focus Border Settings

    @Published var focusBorderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(focusBorderEnabled, forKey: StorageKeys.focusBorderEnabled)
            logger.debug("Focus border visibility set to \(focusBorderEnabled)")
        }
    }

    @Published var focusBorderWidth: Double {
        didSet {
            UserDefaults.standard.set(focusBorderWidth, forKey: StorageKeys.focusBorderWidth)
            logger.debug("Focus border width set to \(focusBorderWidth)pt")
        }
    }

    @Published var focusBorderColor: Color {
        didSet {
            UserDefaults.standard.setColor(focusBorderColor, forKey: StorageKeys.focusBorderColor)
            logger.debug("Focus border color updated")
        }
    }

    // MARK: - Title Overlay Settings

    @Published var sourceTitleEnabled: Bool {
        didSet {
            UserDefaults.standard.set(sourceTitleEnabled, forKey: StorageKeys.sourceTitleEnabled)
            logger.debug("Source title visibility set to \(sourceTitleEnabled)")
        }
    }

    @Published var sourceTitleFontSize: Double {
        didSet {
            UserDefaults.standard.set(sourceTitleFontSize, forKey: StorageKeys.sourceTitleFontSize)
            logger.debug("Source itle font size set to \(sourceTitleFontSize)pt")
        }
    }

    @Published var sourceTitleBackgroundOpacity: Double {
        didSet {
            UserDefaults.standard.set(
                sourceTitleBackgroundOpacity,
                forKey: StorageKeys.sourceTitleBackgroundOpacity
            )
            logger.debug(
                "Source title background opacity set to \(Int(sourceTitleBackgroundOpacity * 100))%"
            )
        }
    }

    // MARK: - Preview Settings

    @Published var previewOpacity: Double {
        didSet {
            UserDefaults.standard.set(previewOpacity, forKey: StorageKeys.previewOpacity)
            logger.debug("Preview window opacity updated to \(Int(previewOpacity * 100))%")
        }
    }

    @Published var previewCloseOnCaptureStop: Bool {
        didSet {
            UserDefaults.standard.set(
                previewCloseOnCaptureStop, forKey: StorageKeys.previewCloseOnCaptureStop)
            logger.debug("Close on capture stop set to \(previewCloseOnCaptureStop)")
        }
    }

    @Published var previewHideInactiveApplications: Bool {
        didSet {
            UserDefaults.standard.set(
                previewHideInactiveApplications,
                forKey: StorageKeys.previewHideInactiveApplications
            )
            logger.debug("Hide inactive applications set to \(previewHideInactiveApplications)")
        }
    }

    @Published var previewHideActiveWindow: Bool {
        didSet {
            UserDefaults.standard.set(
                previewHideActiveWindow, forKey: StorageKeys.previewHideActiveWindow)
            logger.debug("Hide active window set to \(previewHideActiveWindow)")
        }
    }


    @Published var windowShadowEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                windowShadowEnabled, forKey: StorageKeys.windowShadowEnabled)
            logger.debug("Window shadow enabled set to \(windowShadowEnabled)")
        }
    }


    // MARK: - Window Settings

    @Published var windowDefaultWidth: Double {
        didSet {
            UserDefaults.standard.set(windowDefaultWidth, forKey: StorageKeys.windowDefaultWidth)
            logger.debug("Default preview window width set to \(Int(windowDefaultWidth))px")
        }
    }

    @Published var windowDefaultHeight: Double {
        didSet {
            UserDefaults.standard.set(
                windowDefaultHeight, forKey: StorageKeys.windowDefaultHeight)
            logger.debug("Default preview window height set to \(Int(windowDefaultHeight))px")
        }
    }

    @Published var windowManagedByMissionControl: Bool {
        didSet {
            UserDefaults.standard.set(
                windowManagedByMissionControl,
                forKey: StorageKeys.windowManagedByMissionControl
            )
            logger.debug("Mission Control integration set to \(windowManagedByMissionControl)")
        }
    }

    @Published var windowAlignmentEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                windowAlignmentEnabled,
                forKey: StorageKeys.windowAlignmentEnabled
            )
            logger.debug("Edit mode alignment set to \(windowAlignmentEnabled)")
        }
    }

    // MARK: - Capture Settings

    @Published var captureFrameRate: Double {
        didSet {
            UserDefaults.standard.set(captureFrameRate, forKey: StorageKeys.captureFrameRate)
            logger.debug("Frame rate updated to \(Int(captureFrameRate)) FPS")
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

    @Published var filterAppNames: [String] {
        didSet {
            UserDefaults.standard.set(filterAppNames, forKey: StorageKeys.filterAppNames)
            logger.debug("App filter names updated: count=\(filterAppNames.count)")
        }
    }

    @Published var filterBlocklist: Bool {
        didSet {
            UserDefaults.standard.set(filterBlocklist, forKey: StorageKeys.filterBlocklist)
            logger.debug("Filter is blocklist=\(filterBlocklist)")
        }
    }

    // MARK: - Initialization

    init() {
        logger.debug("Initializing settings manager")

        // Initialize with default values
        self.focusBorderEnabled = Defaults.focusBorderEnabled
        self.focusBorderWidth = Defaults.focusBorderWidth
        self.focusBorderColor = Defaults.focusBorderColor
        self.sourceTitleEnabled = Defaults.sourceTitleEnabled
        self.sourceTitleFontSize = Defaults.sourceTitleFontSize
        self.sourceTitleBackgroundOpacity = Defaults.sourceTitleBackgroundOpacity
        self.previewOpacity = Defaults.previewOpacity
        self.windowDefaultWidth = Defaults.windowDefaultWidth
        self.windowDefaultHeight = Defaults.windowDefaultHeight
        self.windowManagedByMissionControl = Defaults.windowManagedByMissionControl
        self.windowShadowEnabled = Defaults.windowShadowEnabled
        self.previewCloseOnCaptureStop = Defaults.previewCloseOnCaptureStop
        self.previewHideInactiveApplications = Defaults.previewHideInactiveApplications
        self.previewHideActiveWindow = Defaults.previewHideActiveWindow
        self.windowAlignmentEnabled = Defaults.windowAlignmentEnabled
        self.hotkeyBindings = Defaults.hotkeyBindings
        self.captureFrameRate = Defaults.captureFrameRate
        self.filterAppNames = Defaults.filterAppNames
        self.filterBlocklist = Defaults.filterBlocklist

        initializeFromStorage()
        loadHotkeyBindings()
        validateSettings()

        isInitializing = false
        logger.debug("Settings manager initialization complete")
    }

    // MARK: - Public Methods

    func resetToDefaults() {
        logger.debug("Initiating settings reset")

        let domain: String = Bundle.main.bundleIdentifier ?? "Overview"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        focusBorderEnabled = Defaults.focusBorderEnabled
        focusBorderWidth = Defaults.focusBorderWidth
        focusBorderColor = Defaults.focusBorderColor
        sourceTitleEnabled = Defaults.sourceTitleEnabled
        sourceTitleFontSize = Defaults.sourceTitleFontSize
        sourceTitleBackgroundOpacity = Defaults.sourceTitleBackgroundOpacity
        previewOpacity = Defaults.previewOpacity
        windowDefaultWidth = Defaults.windowDefaultWidth
        windowDefaultHeight = Defaults.windowDefaultHeight
        windowManagedByMissionControl = Defaults.windowManagedByMissionControl
        windowShadowEnabled = Defaults.windowShadowEnabled
        previewCloseOnCaptureStop = Defaults.previewCloseOnCaptureStop
        previewHideInactiveApplications = Defaults.previewHideInactiveApplications
        previewHideActiveWindow = Defaults.previewHideActiveWindow
        windowAlignmentEnabled = Defaults.windowAlignmentEnabled
        hotkeyBindings = Defaults.hotkeyBindings
        captureFrameRate = Defaults.captureFrameRate
        filterAppNames = Defaults.filterAppNames
        filterBlocklist = Defaults.filterBlocklist

        clearHotkeyBindings()
        logger.info("Settings reset completed successfully")
    }

    // MARK: - Private Methods

    private func initializeFromStorage() {
        logger.debug("Loading settings from storage")

        focusBorderEnabled = UserDefaults.standard.bool(forKey: StorageKeys.focusBorderEnabled)
        focusBorderWidth = UserDefaults.standard.double(forKey: StorageKeys.focusBorderWidth)
        focusBorderColor = UserDefaults.standard.color(forKey: StorageKeys.focusBorderColor)
        sourceTitleEnabled = UserDefaults.standard.bool(forKey: StorageKeys.sourceTitleEnabled)
        sourceTitleFontSize = UserDefaults.standard.double(forKey: StorageKeys.sourceTitleFontSize)
        sourceTitleBackgroundOpacity = UserDefaults.standard.double(
            forKey: StorageKeys.sourceTitleBackgroundOpacity)
        previewOpacity = UserDefaults.standard.double(forKey: StorageKeys.previewOpacity)
        windowDefaultWidth = UserDefaults.standard.double(forKey: StorageKeys.windowDefaultWidth)
        windowDefaultHeight = UserDefaults.standard.double(
            forKey: StorageKeys.windowDefaultHeight)
        windowManagedByMissionControl = UserDefaults.standard.bool(
            forKey: StorageKeys.windowManagedByMissionControl)
        windowShadowEnabled = UserDefaults.standard.bool(
            forKey: StorageKeys.windowShadowEnabled)            
        previewCloseOnCaptureStop = UserDefaults.standard.bool(
            forKey: StorageKeys.previewCloseOnCaptureStop)
        previewHideInactiveApplications = UserDefaults.standard.bool(
            forKey: StorageKeys.previewHideInactiveApplications)
        previewHideActiveWindow = UserDefaults.standard.bool(
            forKey: StorageKeys.previewHideActiveWindow)
        windowAlignmentEnabled = UserDefaults.standard.bool(
            forKey: StorageKeys.windowAlignmentEnabled)
        captureFrameRate = UserDefaults.standard.double(forKey: StorageKeys.captureFrameRate)
        filterAppNames =
            UserDefaults.standard.array(
                forKey: StorageKeys.filterAppNames) as? [String] ?? []
        filterBlocklist = UserDefaults.standard.bool(
            forKey: StorageKeys.filterBlocklist)
    }

    private func loadHotkeyBindings() {
        logger.debug("Loading hotkey bindings from storage")

        guard let data = UserDefaults.standard.data(forKey: StorageKeys.hotkeyBindings),
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

        validateFocusBorderWidth()
        validateSourceTitleSettings()
        validatePreviewOpacity()
        validateCaptureFrameRate()
        validatePreviewWindowDimensions()

        logger.debug("Settings validation complete")
    }

    private func validatePreviewOpacity() {
        guard previewOpacity < 0.05 || previewOpacity > 1.0 else { return }
        logger.warning("Invalid preview opacity value (\(previewOpacity)), resetting to default")
        previewOpacity = Defaults.previewOpacity
    }

    private func validateCaptureFrameRate() {
        guard !availableCaptureFrameRates.contains(captureFrameRate) else { return }
        logger.warning("Invalid capture frame rate (\(captureFrameRate)), resetting to default")
        captureFrameRate = Defaults.captureFrameRate
    }

    private func validatePreviewWindowDimensions() {
        if windowDefaultWidth < 100 {
            logger.warning(
                "Invalid preview window width (\(windowDefaultWidth)), resetting to default")
            windowDefaultWidth = Defaults.windowDefaultWidth
        }
        if windowDefaultHeight < 100 {
            logger.warning(
                "Invalid preview window height (\(windowDefaultHeight)), resetting to default")
            windowDefaultHeight = Defaults.windowDefaultHeight
        }
    }

    private func validateFocusBorderWidth() {
        guard focusBorderWidth <= 0 else { return }
        logger.warning("Invalid focus border width (\(focusBorderWidth)), resetting to default")
        focusBorderWidth = Defaults.focusBorderWidth
    }

    private func validateSourceTitleSettings() {
        if sourceTitleFontSize <= 0 {
            logger.warning(
                "Invalid source title font size (\(sourceTitleFontSize)), resetting to default")
            sourceTitleFontSize = Defaults.sourceTitleFontSize
        }
        if sourceTitleBackgroundOpacity < 0.0 || sourceTitleBackgroundOpacity > 1.0 {
            logger.warning(
                "Invalid source title background opacity (\(sourceTitleBackgroundOpacity)), resetting to default"
            )
            sourceTitleBackgroundOpacity = Defaults.sourceTitleBackgroundOpacity
        }
    }
}

// MARK: - Storage Keys

private enum StorageKeys {
    static let focusBorderEnabled: String = "showFocusedBorder"
    static let focusBorderWidth: String = "focusBorderWidth"
    static let focusBorderColor: String = "focusBorderColor"
    static let sourceTitleEnabled: String = "showWindowTitle"
    static let sourceTitleFontSize: String = "titleFontSize"
    static let sourceTitleBackgroundOpacity: String = "titleBackgroundOpacity"
    static let previewOpacity: String = "windowOpacity"
    static let windowDefaultWidth: String = "defaultWindowWidth"
    static let windowDefaultHeight: String = "defaultWindowHeight"
    static let windowManagedByMissionControl: String = "managedByMissionControl"
    static let windowShadowEnabled: String = "windowShadowEnabled"
    static let previewCloseOnCaptureStop: String = "closeOnCaptureStop"
    static let previewHideInactiveApplications: String = "hideInactiveApplications"
    static let previewHideActiveWindow: String = "hideActiveWindow"
    static let windowAlignmentEnabled: String = "enableEditModeAlignment"
    static let captureFrameRate: String = "frameRate"
    static let hotkeyBindings: String = "hotkeyBindings"
    static let filterAppNames: String = "appFilterNames"
    static let filterBlocklist: String = "isFilterBlocklist"
}
