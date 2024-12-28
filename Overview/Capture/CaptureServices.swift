/*
 Capture/CaptureServices.swift
 Overview

 Created by William Pierce on 12/27/24.
*/

import ScreenCaptureKit

@MainActor
final class CaptureServices {
    static let shared = CaptureServices()
    let captureAvailability = CaptureAvailabilityService()
    let captureConfiguration = CaptureConfigurationService()
    private let logger = AppLogger.capture

    private init() {
        logger.debug("Initializing capture services container")
    }
}
