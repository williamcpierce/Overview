/*
 Window/WindowManager.swift
 Overview

 Created by William Pierce on 12/10/24.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class WindowManager: ObservableObject {
    private let logger = AppLogger.windows
    private let windowServices = WindowServices.shared
    private let captureServices = CaptureServices.shared

    func getFilteredWindows() async -> [SCWindow] {
        do {
            let systemWindows = try await captureServices.captureAvailability.getAvailableWindows()
            let filteredWindows = windowServices.windowFilter.filterWindows(systemWindows)
            return filteredWindows
        } catch {
            logger.logError(
                error,
                context: "Failed to get available windows from system"
            )
            return []
        }
    }

    @discardableResult
    func focusWindow(withTitle title: String) -> Bool {
        let success = windowServices.windowFocus.focusWindow(withTitle: title)
        if !success {
            logger.error("Failed to activate window process: '\(title)'")
        }
        return success
    }

}
