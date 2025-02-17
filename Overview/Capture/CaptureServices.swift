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
    private let engine: CaptureEngine
    private let configService: CaptureConfigurationService
    private let availabilityService: CaptureAvailabilityService
    private let logger = AppLogger.capture

    // Singleton
    static let shared = CaptureServices()

    private init() {
        self.engine = CaptureEngine()
        self.configService = CaptureConfigurationService()
        self.availabilityService = CaptureAvailabilityService()
        logger.debug("Initializing capture services")
    }

    // MARK: - Public Interface

    func getAvailableSources() async throws -> [SCWindow] {
        try await availabilityService.getAvailableSources()
    }

    func startCapture(
        source: SCWindow,
        frameRate: Double
    ) async throws -> AsyncThrowingStream<CapturedFrame, Error> {
        let (config, filter) = configService.createConfiguration(source, frameRate: frameRate)
        return engine.startCapture(configuration: config, filter: filter)
    }

    func stopCapture() async {
        await engine.stopCapture()
    }

    func updateStreamConfiguration(
        source: SCWindow,
        frameRate: Double
    ) async throws {
        try await configService.updateConfiguration(engine.stream, source, frameRate: frameRate)
    }
}
