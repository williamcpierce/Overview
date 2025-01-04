/*
 Capture/CaptureServices.swift
 Overview

 Created by William Pierce on 12/27/24.
*/

import ScreenCaptureKit

@MainActor
final class CaptureServices {
    private let logger = AppLogger.capture
    private let configService = CaptureConfigurationService()
    private let availabilityService = CaptureAvailabilityService()
    static let shared = CaptureServices()

    private init() {
        logger.debug("Initializing capture services")
    }

    func requestScreenRecordingPermission() async throws {
        try await availabilityService.requestPermission()
    }

    func getAvailableWindows() async throws -> [SCWindow] {
        let availableWindows = try await availabilityService.getAvailableWindows()
        return availableWindows
    }

    func startCapture(
        window: SCWindow,
        engine: CaptureEngine,
        frameRate: Double
    ) async throws -> AsyncThrowingStream<CapturedFrame, Error> {
        let (config, filter) = configService.createConfiguration(window, frameRate: frameRate)
        return engine.startCapture(configuration: config, filter: filter)
    }

    func updateStreamConfiguration(
        window: SCWindow,
        stream: SCStream?,
        frameRate: Double
    ) async throws {
        try await configService.updateConfiguration(stream, window, frameRate: frameRate)
    }
}

enum CaptureError: LocalizedError {
    case noWindowSelected
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noWindowSelected:
            return "No window is selected for capture"
        case .permissionDenied:
            return "Screen capture permission was denied"
        }
    }
}
