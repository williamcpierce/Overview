/*
 Window/WindowServices.swift
 Overview

 Created by William Pierce on 1/14/25.

 Provides centralized access to window services.
*/

import ScreenCaptureKit

@MainActor
final class WindowServices {
    // Dependencies
    let windowAspect: WindowAspectService
    let windowConfiguration: WindowConfigurationService
    let windowPosition: WindowPositionService
    private let logger = AppLogger.interface

    // Singleton
    static let shared = WindowServices()

    private init(
        windowAspect: WindowAspectService = WindowAspectService(),
        windowConfiguration: WindowConfigurationService = WindowConfigurationService(),
        windowPosition: WindowPositionService = WindowPositionService()
    ) {
        self.windowAspect = windowAspect
        self.windowConfiguration = windowConfiguration
        self.windowPosition = windowPosition
        logger.debug("Initializing window services")
    }
}
