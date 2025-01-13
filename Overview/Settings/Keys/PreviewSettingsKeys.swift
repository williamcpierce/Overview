/*
 Settings/PreviewSettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.

 Defines storage keys for preview-related settings.
*/

enum PreviewSettingsKeys {
    static let hideInactiveApplications = "hideInactiveApplications"
    static let hideActiveWindow = "hideActiveWindow"
    static let captureFrameRate = "frameRate"

    static let defaults = Defaults()

    struct Defaults {
        let hideInactiveApplications: Bool = false
        let hideActiveWindow: Bool = false
        let captureFrameRate: Double = 10.0

        let availableCaptureFrameRates: [Double] = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]
    }
}
