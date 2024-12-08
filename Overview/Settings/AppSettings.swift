/*
 AppSettings.swift
 Overview

 Created by William Pierce on 10/13/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import Foundation

/// Manages persistent application settings and broadcasts changes to observers
///
/// Key responsibilities:
/// - Persists user preferences using UserDefaults
/// - Provides default values for first-time app launch
/// - Broadcasts setting changes via @Published properties
///
/// Coordinates with:
/// - CaptureManager: Provides frame rate and window settings
/// - WindowAccessor: Controls window appearance and behavior settings
/// - PreviewView: Configures preview window visual properties
class AppSettings: ObservableObject {
    // MARK: - Visual Properties

    /// Window transparency level (0.05-1.0)
    @Published var opacity: Double = UserDefaults.standard.double(forKey: "windowOpacity") {
        didSet { UserDefaults.standard.set(opacity, forKey: "windowOpacity") }
    }

    /// Capture refresh rate in frames per second
    @Published var frameRate: Double = UserDefaults.standard.double(forKey: "frameRate") {
        didSet { UserDefaults.standard.set(frameRate, forKey: "frameRate") }
    }

    // MARK: - Window Dimensions

    /// Initial window width in pixels for new preview windows
    @Published var defaultWindowWidth: Double = UserDefaults.standard.double(
        forKey: "defaultWindowWidth")
    {
        didSet { UserDefaults.standard.set(defaultWindowWidth, forKey: "defaultWindowWidth") }
    }

    /// Initial window height in pixels for new preview windows
    @Published var defaultWindowHeight: Double = UserDefaults.standard.double(
        forKey: "defaultWindowHeight")
    {
        didSet { UserDefaults.standard.set(defaultWindowHeight, forKey: "defaultWindowHeight") }
    }

    // MARK: - UI Options

    /// Whether to display a border around the active source window
    @Published var showFocusedBorder: Bool = UserDefaults.standard.bool(forKey: "showFocusedBorder")
    {
        didSet { UserDefaults.standard.set(showFocusedBorder, forKey: "showFocusedBorder") }
    }

    /// Whether to display the source window's title in the preview
    @Published var showWindowTitle: Bool = UserDefaults.standard.bool(forKey: "showWindowTitle") {
        didSet { UserDefaults.standard.set(showWindowTitle, forKey: "showWindowTitle") }
    }

    // MARK: - Window Management

    /// Whether preview windows appear in Mission Control
    @Published var managedByMissionControl: Bool = UserDefaults.standard.bool(
        forKey: "managedByMissionControl")
    {
        didSet {
            UserDefaults.standard.set(managedByMissionControl, forKey: "managedByMissionControl")
        }
    }

    /// Whether to adjust window level during edit mode to assist with positioning
    @Published var enableEditModeAlignment: Bool = UserDefaults.standard.bool(
        forKey: "enableEditModeAlignment")
    {
        didSet {
            UserDefaults.standard.set(enableEditModeAlignment, forKey: "enableEditModeAlignment")
        }
    }

    // MARK: - Initialization

    /// Creates settings manager and establishes default values if not previously set
    init() {
        /// Set initial values for first launch
        if UserDefaults.standard.double(forKey: "windowOpacity") == 0 { opacity = 0.95 }
        if UserDefaults.standard.double(forKey: "frameRate") == 0 { frameRate = 30 }
        if UserDefaults.standard.double(forKey: "defaultWindowWidth") == 0 {
            defaultWindowWidth = 288
        }
        if UserDefaults.standard.double(forKey: "defaultWindowHeight") == 0 {
            defaultWindowHeight = 162
        }
    }

    // MARK: - Computed Properties

    /// Convenience accessor for default window dimensions
    var defaultWindowSize: CGSize {
        CGSize(width: defaultWindowWidth, height: defaultWindowHeight)
    }
}
