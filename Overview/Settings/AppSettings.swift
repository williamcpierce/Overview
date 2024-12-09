/*
 AppSettings.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages persistent application settings and preferences using UserDefaults,
 providing real-time updates across the application through Combine.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import Foundation
import AppKit

/// Manages persistent application settings and real-time preference updates
///
/// Key responsibilities:
/// - Maintains core application preferences in UserDefaults
/// - Broadcasts setting changes via Combine publishers
/// - Validates setting values for consistency
/// - Provides default configurations for new installations
///
/// Coordinates with:
/// - CaptureManager: Provides capture configuration settings
/// - WindowAccessor: Controls window appearance and behavior
/// - PreviewView: Configures preview window properties
/// - SettingsView: Enables preference modification
class AppSettings: ObservableObject {
    // MARK: - Visual Settings

    /// Preview window transparency level (0.05-1.0)
    /// - Note: Values outside range are clamped during validation
    @Published var opacity: Double = UserDefaults.standard.double(forKey: "windowOpacity") {
        didSet {
            let clampedValue = max(0.05, min(1.0, opacity))
            UserDefaults.standard.set(clampedValue, forKey: "windowOpacity")
        }
    }

    /// Window capture refresh rate in frames per second
    /// - Note: Valid values are 1, 5, 10, 30, 60, 120
    /// - Warning: Changes require CaptureEngine stream reconfiguration
    @Published var frameRate: Double = UserDefaults.standard.double(forKey: "frameRate") {
        didSet {
            UserDefaults.standard.set(frameRate, forKey: "frameRate")
        }
    }

    // MARK: - Window Dimensions

    /// Default width for new preview windows
    /// - Note: Maintains aspect ratio with height
    @Published var defaultWindowWidth: Double = UserDefaults.standard.double(
        forKey: "defaultWindowWidth")
    {
        didSet {
            UserDefaults.standard.set(defaultWindowWidth, forKey: "defaultWindowWidth")
        }
    }

    /// Default height for new preview windows
    /// - Note: Maintains aspect ratio with width
    @Published var defaultWindowHeight: Double = UserDefaults.standard.double(
        forKey: "defaultWindowHeight")
    {
        didSet {
            UserDefaults.standard.set(defaultWindowHeight, forKey: "defaultWindowHeight")
        }
    }

    // MARK: - UI Options

    /// Indicates whether to highlight the currently focused window
    /// - Note: Border only appears when source window has focus
    @Published var showFocusedBorder: Bool = UserDefaults.standard.bool(forKey: "showFocusedBorder")
    {
        didSet {
            UserDefaults.standard.set(showFocusedBorder, forKey: "showFocusedBorder")
        }
    }

    /// Indicates whether to show source window title in preview
    @Published var showWindowTitle: Bool = UserDefaults.standard.bool(forKey: "showWindowTitle") {
        didSet {
            UserDefaults.standard.set(showWindowTitle, forKey: "showWindowTitle")
        }
    }

    // MARK: - Window Management

    /// Controls preview window visibility in Mission Control
    /// - Warning: Requires window recreation to take effect
    @Published var managedByMissionControl: Bool = UserDefaults.standard.bool(
        forKey: "managedByMissionControl")
    {
        didSet {
            UserDefaults.standard.set(managedByMissionControl, forKey: "managedByMissionControl")
        }
    }

    /// Controls window level adjustment during edit mode
    /// - Note: Lower window level helps with alignment to other windows
    @Published var enableEditModeAlignment: Bool = UserDefaults.standard.bool(
        forKey: "enableEditModeAlignment")
    {
        didSet {
            UserDefaults.standard.set(enableEditModeAlignment, forKey: "enableEditModeAlignment")
        }
    }
    
    @Published var hotkeyBindings: [HotkeyBinding] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(hotkeyBindings) {
                UserDefaults.standard.set(encoded, forKey: "hotkeyBindings")
            }
        }
    }

    // MARK: - Initialization

    /// Initializes settings with defaults and validates stored values
    ///
    /// Flow:
    /// 1. Checks for existing preferences in UserDefaults
    /// 2. Applies defaults for missing settings
    /// 3. Validates all values meet requirements
    init() {
        // Apply defaults for first launch
        if UserDefaults.standard.double(forKey: "windowOpacity") == 0 {
            opacity = 0.95  // High visibility default
        }
        if UserDefaults.standard.double(forKey: "frameRate") == 0 {
            frameRate = 30  // Balance performance/smoothness
        }
        if UserDefaults.standard.double(forKey: "defaultWindowWidth") == 0 {
            defaultWindowWidth = 288  // 16:9 aspect ratio
        }
        if UserDefaults.standard.double(forKey: "defaultWindowHeight") == 0 {
            defaultWindowHeight = 162  // 16:9 aspect ratio
        }
        if let data = UserDefaults.standard.data(forKey: "hotkeyBindings"),
           let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data) {
            hotkeyBindings = decoded
        }

        validateSettings()
    }

    // MARK: - Private Methods

    /// Validates and corrects settings values
    private func validateSettings() {
        // Clamp opacity to valid range
        if opacity < 0.05 || opacity > 1.0 {
            opacity = max(0.05, min(1.0, opacity))
        }

        // Ensure frame rate is supported
        let validRates = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]
        if !validRates.contains(frameRate) {
            frameRate = 30.0
        }

        // Enforce minimum window dimensions
        if defaultWindowWidth < 100 {
            defaultWindowWidth = 288
        }
        if defaultWindowHeight < 100 {
            defaultWindowHeight = 162
        }
    }

    // MARK: - Computed Properties

    /// Provides default window size as CGSize
    var defaultWindowSize: CGSize {
        CGSize(width: defaultWindowWidth, height: defaultWindowHeight)
    }
    
    func resetToDefaults() {
        let domain = Bundle.main.bundleIdentifier ?? "Overview"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        // Reinitialize with defaults
        opacity = 0.95
        frameRate = 30.0
        defaultWindowWidth = 288
        defaultWindowHeight = 162
        showFocusedBorder = false
        showWindowTitle = false
        managedByMissionControl = false
        enableEditModeAlignment = false
        hotkeyBindings = []
    }
}

struct HotkeyBinding: Codable, Equatable, Hashable {
    let windowTitle: String
    let keyCode: Int
    private let modifierFlags: UInt
    
    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags)
    }
    
    init(windowTitle: String, keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        self.windowTitle = windowTitle
        self.keyCode = keyCode
        // Only store the relevant modifier flags
        self.modifierFlags = modifiers.intersection([.command, .option, .control, .shift]).rawValue
    }
    
    // Custom Codable implementation
    enum CodingKeys: String, CodingKey {
        case windowTitle, keyCode, modifierFlags
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        windowTitle = try container.decode(String.self, forKey: .windowTitle)
        keyCode = try container.decode(Int.self, forKey: .keyCode)
        modifierFlags = try container.decode(UInt.self, forKey: .modifierFlags)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(windowTitle, forKey: .windowTitle)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifierFlags, forKey: .modifierFlags)
    }
    
    // MARK: - Hashable Implementation
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(windowTitle)
        hasher.combine(keyCode)
        hasher.combine(modifierFlags)
    }
}
