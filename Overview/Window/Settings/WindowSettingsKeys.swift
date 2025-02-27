/*
 Window/Settings/WindowSettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.

 Defines storage keys for window-related settings.
*/

enum WindowSettingsKeys {
    static let previewOpacity: String = "windowOpacity"
    static let defaultWidth: String = "defaultWindowWidth"
    static let defaultHeight: String = "defaultWindowHeight"
    static let shadowEnabled: String = "windowShadowEnabled"
    static let syncAspectRatio: String = "syncAspectRatio"

    static let managedByMissionControl: String = "managedByMissionControl"
    static let assignPreviewsToAllDesktops: String = "desktopAssignmentBehavior"

    static let createOnLaunch: String = "windowCreateOnLaunch"
    static let closeOnCaptureStop: String = "closeOnCaptureStop"
    static let saveWindowsOnQuit: String = "savePositionsOnClose"
    static let restoreWindowsOnLaunch: String = "restoreWindowsOnLaunch"

    static let storedWindows: String = "StoredWindowPositions"

    static let defaults = Defaults()

    struct Defaults {
        let previewOpacity: Double = 0.95
        let defaultWidth: Double = 288
        let defaultHeight: Double = 162
        let shadowEnabled: Bool = true
        let syncAspectRatio: Bool = true

        let managedByMissionControl: Bool = true
        let assignPreviewsToAllDesktops: Bool = false

        let createOnLaunch: Bool = true
        let closeOnCaptureStop: Bool = false
        let saveWindowsOnQuit: Bool = true
        let restoreWindowsOnLaunch: Bool = true
    }
}
