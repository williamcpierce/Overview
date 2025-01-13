/*
 Settings/Keys/Keys/WindowSettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.

 Defines storage keys for window-related settings.
*/

enum WindowSettingsKeys {
    static let previewOpacity: String = "windowOpacity"
    static let defaultWidth: String = "defaultWindowWidth"
    static let defaultHeight: String = "defaultWindowHeight"
    static let managedByMissionControl: String = "managedByMissionControl"
    static let shadowEnabled: String = "windowShadowEnabled"
    static let createOnLaunch: String = "windowCreateOnLaunch"
    static let alignmentEnabled: String = "enableEditModeAlignment"
    static let closeOnCaptureStop: String = "closeOnCaptureStop"

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
