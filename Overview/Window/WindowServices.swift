/*
 Window/WindowServices.swift
 Overview

 Created by William Pierce on 12/15/24.

 Provides centralized access to window-related services including filtering,
 focus management, and state observation.
*/

import ScreenCaptureKit

/// Coordinates window-related services and provides centralized access to
/// window management functionality across the application.
@MainActor
final class WindowServices {
    let windowFilter: WindowFilterService
    let windowFocus: WindowFocusService
    let windowObserver: WindowObserverService
    private let logger = AppLogger.windows
    static let shared = WindowServices()

    private init(
        windowFilter: WindowFilterService = WindowFilterService(),
        windowFocus: WindowFocusService = WindowFocusService(),
        windowObserver: WindowObserverService = WindowObserverService()
    ) {
        self.windowFilter = windowFilter
        self.windowFocus = windowFocus
        self.windowObserver = windowObserver
        logger.debug("Initializing window services")
    }
}
