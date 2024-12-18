/*
 Window/WindowServices.swift
 Overview

 Created by William Pierce on 12/15/24.

 Provides a service-oriented architecture for window management, offering a set of
 specialized services for window filtering, focusing, title tracking, and state
 observation through a centralized singleton container.
*/

import ScreenCaptureKit

@MainActor
final class WindowServices {
    static let shared = WindowServices()

    let windowFilter = WindowFilterService()
    let windowFocus = WindowFocusService()
    let titleService = WindowTitleService()
    let windowObserver = WindowObserverService()

    private init() {
        AppLogger.windows.info("Initializing window services container")
    }
}
