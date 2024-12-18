/*
 AppSettings.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages application preferences and settings persistence, providing real-time updates
 across the application through Combine publishers and UserDefaults storage.
*/

import Foundation
import SwiftUI

/// Manages persistent application settings and real-time preference updates
///
/// Key responsibilities:
/// - Maintains core application preferences in UserDefaults storage
/// - Broadcasts setting changes via Combine publishers
/// - Validates setting values for consistency and safety
/// - Provides default configurations for new installations
///
/// Coordinates with:
/// - CaptureManager: Provides capture configuration settings
/// - PreviewAccessor: Controls preview window appearance and behavior
/// - PreviewView: Configures preview window properties
/// - SettingsView: Enables preference modification
/// - HotkeyService: Manages keyboard shortcut registration
class AppSettings: ObservableObject {
    // MARK: - Properties

    /// Prevents hotkey registration during initialization
    private var isInitializing = true

    // MARK: - Visual Settings

    /// Preview window transparency level (0.05-1.0)
    /// - Note: Values outside range are clamped during validation
    @Published var opacity: Double = UserDefaults.standard.double(forKey: "windowOpacity") {
        didSet {
            let clampedValue = max(0.05, min(1.0, opacity))
            UserDefaults.standard.set(clampedValue, forKey: "windowOpacity")
            AppLogger.settings.info("Window opacity updated to \(Int(clampedValue * 100))%")
        }
    }

    /// Window capture refresh rate in frames per second
    /// - Note: Valid values are 1, 5, 10, 30, 60, 120
    /// - Warning: Changes require CaptureEngine stream reconfiguration
    @Published var frameRate: Double = UserDefaults.standard.double(forKey: "frameRate") {
        didSet {
            UserDefaults.standard.set(frameRate, forKey: "frameRate")
            AppLogger.settings.info("Frame rate updated to \(Int(frameRate)) FPS")
        }
    }

    // MARK: - Window Dimensions

    /// Default width for new preview windows
    /// - Note: Used in combination with height to maintain aspect ratio
    @Published var defaultWindowWidth: Double = UserDefaults.standard.double(
        forKey: "defaultWindowWidth")
    {
        didSet {
            UserDefaults.standard.set(defaultWindowWidth, forKey: "defaultWindowWidth")
            AppLogger.settings.info("Default window width set to \(Int(defaultWindowWidth))px")
        }
    }

    /// Default height for new preview windows
    /// - Note: Used in combination with width to maintain aspect ratio
    @Published var defaultWindowHeight: Double = UserDefaults.standard.double(
        forKey: "defaultWindowHeight")
    {
        didSet {
            UserDefaults.standard.set(defaultWindowHeight, forKey: "defaultWindowHeight")
            AppLogger.settings.info("Default window height set to \(Int(defaultWindowHeight))px")
        }
    }

    // MARK: - UI Options

    /// Controls visibility of focus indicator border
    /// - Note: Only appears when source window has system focus
    @Published var showFocusedBorder: Bool = UserDefaults.standard.bool(forKey: "showFocusedBorder")
    {
        didSet {
            UserDefaults.standard.set(showFocusedBorder, forKey: "showFocusedBorder")
            AppLogger.settings.info("Focus border visibility set to \(showFocusedBorder)")
        }
    }

    /// Width of the focus border in points
    @Published var focusBorderWidth: Double = UserDefaults.standard.double(
        forKey: "focusBorderWidth")
    {
        didSet {
            UserDefaults.standard.set(focusBorderWidth, forKey: "focusBorderWidth")
            AppLogger.settings.info("Focus border width set to \(focusBorderWidth)pt")
        }
    }

    /// Color of the focus border
    @Published var focusBorderColor: Color = .gray {
        didSet {
            AppLogger.settings.info("Focus border color updated")
        }
    }

    /// Controls visibility of window title overlay
    @Published var showWindowTitle: Bool = UserDefaults.standard.bool(forKey: "showWindowTitle") {
        didSet {
            UserDefaults.standard.set(showWindowTitle, forKey: "showWindowTitle")
            AppLogger.settings.info("Window title visibility set to \(showWindowTitle)")
        }
    }

    /// Font size for the window title overlay
    @Published var titleFontSize: Double = UserDefaults.standard.double(forKey: "titleFontSize") {
        didSet {
            UserDefaults.standard.set(titleFontSize, forKey: "titleFontSize")
            AppLogger.settings.info("Title font size set to \(titleFontSize)pt")
        }
    }

    /// Background opacity for the window title overlay
    @Published var titleBackgroundOpacity: Double = UserDefaults.standard.double(
        forKey: "titleBackgroundOpacity")
    {
        didSet {
            UserDefaults.standard.set(titleBackgroundOpacity, forKey: "titleBackgroundOpacity")
            AppLogger.settings.info(
                "Title background opacity set to \(Int(titleBackgroundOpacity * 100))%")
        }
    }

    // MARK: - Window Management

    /// Controls preview window visibility in Mission Control
    /// - Warning: Changes require window recreation to take effect
    @Published var managedByMissionControl: Bool = UserDefaults.standard.bool(
        forKey: "managedByMissionControl")
    {
        didSet {
            UserDefaults.standard.set(managedByMissionControl, forKey: "managedByMissionControl")
            AppLogger.settings.info("Mission Control integration set to \(managedByMissionControl)")
        }
    }

    /// Controls window level behavior during edit mode
    /// - Note: Lower level improves window alignment capabilities
    @Published var enableEditModeAlignment: Bool = UserDefaults.standard.bool(
        forKey: "enableEditModeAlignment")
    {
        didSet {
            UserDefaults.standard.set(enableEditModeAlignment, forKey: "enableEditModeAlignment")
            AppLogger.settings.info("Edit mode alignment set to \(enableEditModeAlignment)")
        }
    }

    /// Active keyboard shortcuts for window focus operations
    /// - Note: Changes trigger immediate hotkey registration
    @Published var hotkeyBindings: [HotkeyBinding] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(hotkeyBindings) {
                UserDefaults.standard.set(encoded, forKey: "hotkeyBindings")
                // Skip registration during initialization to prevent conflicts
                if !isInitializing {
                    do {
                        try HotkeyService.shared.registerHotkeys(hotkeyBindings)
                        AppLogger.settings.info("Registered \(hotkeyBindings.count) hotkey bindings")
                    } catch {
                        AppLogger.settings.error("Failed to register hotkeys: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Initialization

    /// Creates settings manager with validated defaults
    ///
    /// Flow:
    /// 1. Loads existing settings from UserDefaults
    /// 2. Applies defaults for missing values
    /// 3. Validates all settings meet requirements
    /// 4. Enables hotkey registration after setup
    init() {
        AppLogger.settings.debug("Initializing AppSettings")
        isInitializing = true

        initializeDefaults()
        loadHotkeyBindings()
        validateSettings()

        isInitializing = false
        AppLogger.settings.info("AppSettings initialization complete")
    }

    // MARK: - Public Methods

    /// Resets all settings to default values
    ///
    /// Flow:
    /// 1. Removes existing UserDefaults values
    /// 2. Reapplies default settings
    /// 3. Clears hotkey registrations
    func resetToDefaults() {
        AppLogger.settings.info("Resetting all settings to defaults")

        let domain = Bundle.main.bundleIdentifier ?? "Overview"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        // Window settings
        opacity = 0.95
        frameRate = 30.0
        defaultWindowWidth = 288
        defaultWindowHeight = 162

        // Visibility settings
        showFocusedBorder = false
        showWindowTitle = false
        managedByMissionControl = false
        enableEditModeAlignment = false

        // Focus border settings
        focusBorderWidth = 5.0
        focusBorderColor = .gray

        // Title settings
        titleFontSize = 12.0
        titleBackgroundOpacity = 0.4

        // Clear hotkeys
        hotkeyBindings = []
        do {
            try HotkeyService.shared.registerHotkeys(hotkeyBindings)
            AppLogger.settings.info("Registered \(hotkeyBindings.count) hotkey bindings")
        } catch {
            AppLogger.settings.error("Failed to register hotkeys: \(error.localizedDescription)")
        }

        AppLogger.settings.info("Settings reset completed")
    }

    // MARK: - Private Methods

    /// Initializes default values for first launch
    private func initializeDefaults() {
        AppLogger.settings.debug("Checking for existing settings")

        // Window opacity
        if UserDefaults.standard.double(forKey: "windowOpacity") == 0 {
            AppLogger.settings.info("Applying default opacity")
            opacity = 0.95  // High visibility default
        }

        // Frame rate
        if UserDefaults.standard.double(forKey: "frameRate") == 0 {
            AppLogger.settings.info("Applying default frame rate")
            frameRate = 30  // Balance performance/smoothness
        }

        // Window dimensions
        if UserDefaults.standard.double(forKey: "defaultWindowWidth") == 0 {
            AppLogger.settings.info("Applying default window dimensions")
            defaultWindowWidth = 288  // 16:9 aspect ratio
            defaultWindowHeight = 162
        }

        // Focus border settings
        if UserDefaults.standard.double(forKey: "focusBorderWidth") == 0 {
            AppLogger.settings.info("Applying default focus border settings")
            focusBorderWidth = 5.0
            focusBorderColor = .gray
        }

        // Title settings
        if UserDefaults.standard.double(forKey: "titleFontSize") == 0 {
            AppLogger.settings.info("Applying default title settings")
            titleFontSize = 12.0
            titleBackgroundOpacity = 0.4
        }
    }

    /// Loads saved hotkey bindings from persistent storage
    private func loadHotkeyBindings() {
        if let data = UserDefaults.standard.data(forKey: "hotkeyBindings"),
            let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data)
        {
            AppLogger.settings.info("Loaded \(decoded.count) saved hotkey bindings")
            hotkeyBindings = decoded
        }
    }

    /// Validates and corrects setting values
    private func validateSettings() {
        AppLogger.settings.debug("Validating settings values")

        // Clamp opacity to valid range
        if opacity < 0.05 || opacity > 1.0 {
            AppLogger.settings.warning(
                "Invalid opacity value (\(opacity)), clamping to valid range")
            opacity = max(0.05, min(1.0, opacity))
        }

        // Ensure frame rate is supported
        let validRates = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]
        if !validRates.contains(frameRate) {
            AppLogger.settings.warning("Invalid frame rate (\(frameRate)), defaulting to 30 FPS")
            frameRate = 30.0
        }

        // Enforce minimum window dimensions
        if defaultWindowWidth < 100 {
            AppLogger.settings.warning(
                "Window width too small (\(defaultWindowWidth)), setting to default")
            defaultWindowWidth = 288
        }
        if defaultWindowHeight < 100 {
            AppLogger.settings.warning(
                "Window height too small (\(defaultWindowHeight)), setting to default")
            defaultWindowHeight = 162
        }

        // Validate focus border width
        if focusBorderWidth <= 0 {
            AppLogger.settings.warning(
                "Invalid border width (\(focusBorderWidth)), setting to default")
            focusBorderWidth = 5.0
        }

        // Validate title font size
        if titleFontSize <= 0 {
            AppLogger.settings.warning("Invalid font size (\(titleFontSize)), setting to default")
            titleFontSize = 12.0
        }

        // Clamp title background opacity
        if titleBackgroundOpacity < 0.0 || titleBackgroundOpacity > 1.0 {
            AppLogger.settings.warning(
                "Invalid title background opacity (\(titleBackgroundOpacity)), clamping to valid range"
            )
            titleBackgroundOpacity = max(0.0, min(1.0, titleBackgroundOpacity))
        }

        AppLogger.settings.debug("Settings validation complete")
    }

    // MARK: - Computed Properties

    /// Default window dimensions as CGSize
    var defaultWindowSize: CGSize {
        CGSize(width: defaultWindowWidth, height: defaultWindowHeight)
    }
}
