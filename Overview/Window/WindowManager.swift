/*
 Window/WindowManager.swift
 Overview

 Created by William Pierce on 12/10/24.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class WindowManager: ObservableObject {
    private let captureServices: CaptureServices = CaptureServices.shared
    private let logger = AppLogger.windows
    private let windowServices: WindowServices = WindowServices.shared

    func getFilteredWindows() async -> [SCWindow] {
        do {
            let systemWindows: [SCWindow] = try await captureServices.captureAvailability
                .getAvailableWindows()
            let filteredWindows: [SCWindow] = windowServices.windowFilter.filterWindows(
                systemWindows)
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
        let success: Bool = windowServices.windowFocus.focusWindow(withTitle: title)
        if !success {
            logger.error("Failed to activate window process: '\(title)'")
        }
        return success
    }

}
