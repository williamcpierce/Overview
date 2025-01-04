/*
 Capture/CaptureServices.swift
 Overview

 Created by William Pierce on 12/27/24.
*/

import ScreenCaptureKit

@MainActor
final class CaptureServices {
    let captureAvailability = CaptureAvailabilityService()
    let captureConfiguration = CaptureConfigurationService()
    private let logger = AppLogger.capture
    static let shared = CaptureServices()

    private init() {
        logger.debug("Initializing capture services container")
    }
}
