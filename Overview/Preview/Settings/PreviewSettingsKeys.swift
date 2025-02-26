/*
 Preview/Settings/PreviewSettingsKeys.swift
 Overview

 Created by William Pierce on 1/12/25.

 Defines storage keys for preview-related settings.
*/

enum PreviewSettingsKeys {
    static let captureFrameRate: String = "frameRate"

    static let hideInactiveApplications: String = "hideInactiveApplications"
    static let hideActiveWindow: String = "hideActiveWindow"

    static let defaults = Defaults()

    struct Defaults {
        let captureFrameRate: Double = 10.0

        let hideInactiveApplications: Bool = false
        let hideActiveWindow: Bool = false

        let availableCaptureFrameRates: [Double] = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]
    }
}
