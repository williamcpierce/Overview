/*
 Preview/Settings/PreviewSettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import Defaults

extension Defaults.Keys {
    // Preview Capture Settings
    static let captureFrameRate = Key<Double>("frameRate", default: 10.0)

    // Visibility Settings
    static let hideInactiveApplications = Key<Bool>("hideInactiveApplications", default: false)
    static let hideActiveWindow = Key<Bool>("hideActiveWindow", default: false)
}

// Constants
enum PreviewConstants {
    static let availableCaptureFrameRates: [Double] = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]
}
