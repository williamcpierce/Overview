/*
 Window/Settings/WindowSettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import Defaults
import Foundation

extension Defaults.Keys {
    // Appearance Settings
    static let windowOpacity = Key<Double>("windowOpacity", default: 0.95)
    static let defaultWindowWidth = Key<Double>("defaultWindowWidth", default: 288)
    static let defaultWindowHeight = Key<Double>("defaultWindowHeight", default: 162)
    static let windowShadowEnabled = Key<Bool>("windowShadowEnabled", default: true)
    static let syncAspectRatio = Key<Bool>("syncAspectRatio", default: true)

    // System Visibility Settings
    static let managedByMissionControl = Key<Bool>("managedByMissionControl", default: true)
    static let assignPreviewsToAllDesktops = Key<Bool>("desktopAssignmentBehavior", default: false)

    // Window Management Settings
    static let createOnLaunch = Key<Bool>("windowCreateOnLaunch", default: true)
    static let closeOnCaptureStop = Key<Bool>("closeOnCaptureStop", default: false)
    static let saveWindowsOnQuit = Key<Bool>("savePositionsOnClose", default: true)
    static let restoreWindowsOnLaunch = Key<Bool>("restoreWindowsOnLaunch", default: true)

    // Data Storage Keys
    static let storedWindows = Key<Data?>("StoredWindowPositions", default: nil)
}
