/*
 Settings/WindowSettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.

 Defines storage keys for window-related settings.
*/

enum WindowSettingsKeys {
    static let previewOpacity = "windowOpacity"
    static let defaultWidth = "defaultWindowWidth"
    static let defaultHeight = "defaultWindowHeight"
    static let managedByMissionControl = "managedByMissionControl"
    static let shadowEnabled = "windowShadowEnabled"
    static let createOnLaunch = "windowCreateOnLaunch"
    static let alignmentEnabled = "enableEditModeAlignment"
    static let closeOnCaptureStop = "closeOnCaptureStop"

    static let defaults = Defaults()

    struct Defaults {
        let previewOpacity: Double = 0.95
        let defaultWidth: Double = 288
        let defaultHeight: Double = 162
        let managedByMissionControl: Bool = true
        let shadowEnabled: Bool = false
        let createOnLaunch: Bool = true
        let alignmentEnabled: Bool = false
        let closeOnCaptureStop: Bool = false
    }
}
