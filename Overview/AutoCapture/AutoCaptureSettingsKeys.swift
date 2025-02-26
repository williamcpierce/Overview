/*
 AutoCapture/Settings/AutoCaptureSettingsKeys.swift
 Overview

 Created by William Pierce on 2/25/25.
*/

enum AutoCaptureSettingsKeys {
    static let enabled: String = "autoCaptureEnabled"
    static let applications: String = "autoCaptureApplications"
    static let characterPositions: String = "autoCaptureCharacterPositions"

    static let defaults = Defaults()

    struct Defaults {
        let enabled: Bool = false
        let applications: [String] = ["EVE"]
    }
}
