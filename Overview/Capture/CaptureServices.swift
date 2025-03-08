/*
 Capture/CaptureServices.swift
 Overview

 Created by William Pierce on 12/27/24.

 A centralized service that coordinates capture-related operations,
 including permission management and stream configuration.
*/

import ScreenCaptureKit

@MainActor
final class CaptureServices {
    // Dependencies
    private let configService: CaptureConfigurationService
    private let availabilityService: CaptureAvailabilityService
    private let logger = AppLogger.capture

    // Singleton
    static let shared = CaptureServices()

    private init() {
        self.configService = CaptureConfigurationService()
        self.availabilityService = CaptureAvailabilityService()
        logger.debug("Initializing capture services")
    }

    // MARK: - Public Interface

    func getAvailableSources() async throws -> [SCWindow] {
        try await availabilityService.getAvailableSources()
    }

    func createStreamConfiguration(_ source: SCWindow, frameRate: Double) -> (
        SCStreamConfiguration, SCContentFilter
    ) {
        return configService.createConfiguration(source, frameRate: frameRate)
    }

    func updateStreamConfiguration(
        source: SCWindow,
        stream: SCStream?,
        frameRate: Double
    ) async throws {
        guard let stream = stream else {
            logger.warning("Cannot update configuration: stream is nil")
            return
        }

        try await configService.updateConfiguration(stream, source, frameRate: frameRate)
    }
}
