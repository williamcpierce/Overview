/*
 Window/WindowServices.swift
 Overview

 Created by William Pierce on 12/15/24.
*/

import ScreenCaptureKit

@MainActor
final class WindowServices {
    static let shared = WindowServices()
    let windowFilter = WindowFilterService()
    let windowFocus = WindowFocusService()
    let titleService = WindowTitleService()
    let windowObserver = WindowObserverService()
    private let logger = AppLogger.windows

    private init() {
        logger.debug("Initializing window services container")
    }
}
