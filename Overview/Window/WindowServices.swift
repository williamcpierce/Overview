/*
 Window/WindowServices.swift
 Overview

 Created by William Pierce on 12/15/24.
*/

import ScreenCaptureKit

@MainActor
final class WindowServices {
    let titleService = WindowTitleService()
    let windowFilter = WindowFilterService()
    let windowFocus = WindowFocusService()
    let windowObserver = WindowObserverService()
    private let logger = AppLogger.windows
    static let shared = WindowServices()

    private init() {
        logger.debug("Initializing window services container")
    }
}
