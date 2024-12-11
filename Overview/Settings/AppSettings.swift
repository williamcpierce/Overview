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

class AppSettings: ObservableObject {
    private var isLoadingDefaults = true

    @Published var opacity: Double = UserDefaults.standard.double(forKey: "windowOpacity") {
        didSet {
            let clampedValue = max(0.05, min(1.0, opacity))
            UserDefaults.standard.set(clampedValue, forKey: "windowOpacity")
        }
    }

    @Published var frameRate: Double = UserDefaults.standard.double(forKey: "frameRate") {
        didSet {
            UserDefaults.standard.set(frameRate, forKey: "frameRate")
        }
    }

    @Published var defaultWindowWidth: Double = UserDefaults.standard.double(
        forKey: "defaultWindowWidth")
    {
        didSet {
            UserDefaults.standard.set(defaultWindowWidth, forKey: "defaultWindowWidth")
        }
    }

    @Published var defaultWindowHeight: Double = UserDefaults.standard.double(
        forKey: "defaultWindowHeight")
    {
        didSet {
            UserDefaults.standard.set(defaultWindowHeight, forKey: "defaultWindowHeight")
        }
    }

    @Published var showFocusedBorder: Bool = UserDefaults.standard.bool(forKey: "showFocusedBorder")
    {
        didSet {
            UserDefaults.standard.set(showFocusedBorder, forKey: "showFocusedBorder")
        }
    }

    @Published var showWindowTitle: Bool = UserDefaults.standard.bool(forKey: "showWindowTitle") {
        didSet {
            UserDefaults.standard.set(showWindowTitle, forKey: "showWindowTitle")
        }
    }

    @Published var managedByMissionControl: Bool = UserDefaults.standard.bool(
        forKey: "managedByMissionControl")
    {
        didSet {
            UserDefaults.standard.set(managedByMissionControl, forKey: "managedByMissionControl")
        }
    }

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
                if !isLoadingDefaults {
                    HotkeyService.shared.registerHotkeys(hotkeyBindings)
                }
            }
        }
    }

    init() {
        isLoadingDefaults = true

        if UserDefaults.standard.double(forKey: "windowOpacity") == 0 {
            opacity = 0.95
        }
        if UserDefaults.standard.double(forKey: "frameRate") == 0 {
            frameRate = 30
        }
        if UserDefaults.standard.double(forKey: "defaultWindowWidth") == 0 {
            defaultWindowWidth = 288
        }
        if UserDefaults.standard.double(forKey: "defaultWindowHeight") == 0 {
            defaultWindowHeight = 162
        }

        if let data = UserDefaults.standard.data(forKey: "hotkeyBindings"),
            let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data)
        {
            hotkeyBindings = decoded
        }

        validateAndCorrectSettings()
        isLoadingDefaults = false
    }

    private func validateAndCorrectSettings() {
        if opacity < 0.05 || opacity > 1.0 {
            opacity = max(0.05, min(1.0, opacity))
        }

        let validRates = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]
        if !validRates.contains(frameRate) {
            frameRate = 30.0
        }

        if defaultWindowWidth < 100 {
            defaultWindowWidth = 288
        }
        if defaultWindowHeight < 100 {
            defaultWindowHeight = 162
        }
    }

    var defaultWindowSize: CGSize {
        CGSize(width: defaultWindowWidth, height: defaultWindowHeight)
    }

    func resetToDefaults() {
        let domain = Bundle.main.bundleIdentifier ?? "Overview"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        opacity = 0.95
        frameRate = 30.0
        defaultWindowWidth = 288
        defaultWindowHeight = 162
        showFocusedBorder = false
        showWindowTitle = false
        managedByMissionControl = false
        enableEditModeAlignment = false
        hotkeyBindings = []
        HotkeyService.shared.registerHotkeys([])
    }
}
