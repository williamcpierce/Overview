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
    private let logger = AppLogger.capture

    // Private State
    private let configService = CaptureConfigurationService()
    private let availabilityService = CaptureAvailabilityService()
    
    // Singleton
    static let shared = CaptureServices()

    private init() {
        logger.debug("Initializing capture services")
    }

    func requestScreenRecordingPermission() async throws {
        try await availabilityService.requestPermission()
    }

    func getAvailableSources() async throws -> [SCWindow] {
        let availableSources = try await availabilityService.getAvailableSources()
        return availableSources
    }

    func startCapture(
        source: SCWindow,
        engine: CaptureEngine,
        frameRate: Double
    ) async throws -> AsyncThrowingStream<CapturedFrame, Error> {
        let (config, filter) = configService.createConfiguration(source, frameRate: frameRate)
        return engine.startCapture(configuration: config, filter: filter)
    }

    func updateStreamConfiguration(
        source: SCWindow,
        stream: SCStream?,
        frameRate: Double
    ) async throws {
        try await configService.updateConfiguration(stream, source, frameRate: frameRate)
    }
}

// MARK: - Capture Error

enum CaptureError: LocalizedError {
    case noSourceSelected
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noSourceSelected:
            return "No source window is selected for capture"
        case .permissionDenied:
            return "Screen capture permission was denied"
        }
    }
}
