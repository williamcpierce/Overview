/*
 Window/WindowManager.swift
 Overview

 Created by William Pierce on 12/10/24.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class WindowManager: ObservableObject {
    @Published private(set) var focusedBundleId: String?
    @Published private(set) var windowTitles: [WindowID: String] = [:]

    let windowServices: WindowServices = WindowServices.shared
    private let captureServices: CaptureServices = CaptureServices.shared
    private let logger = AppLogger.windows
    private let observerId = UUID()

    struct WindowID: Hashable {
        let processID: pid_t
        let windowID: CGWindowID
    }

    init() {
        setupObservers()
    }

    @discardableResult
    func focusWindow(withTitle title: String) -> Bool {
        let success = windowServices.windowFocus.focusWindow(withTitle: title)
        if !success {
            logger.error("Failed to activate window: '\(title)'")
        }
        return success
    }

    func getFilteredWindows() async -> [SCWindow] {
        do {
            let windows = try await captureServices.captureAvailability.getAvailableWindows()
            return windowServices.windowFilter.filterWindows(windows)
        } catch {
            logger.logError(error, context: "Failed to get available windows")
            return []
        }
    }

    private func setupObservers() {
        windowServices.windowObserver.addObserver(
            id: observerId,
            onFocusChanged: { [weak self] in await self?.updateFocusedApp() },
            onTitleChanged: { [weak self] in await self?.updateWindowTitles() }
        )
    }

    private func updateFocusedApp() async {
        focusedBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func updateWindowTitles() async {
        do {
            let windows = try await captureServices.captureAvailability.getAvailableWindows()
            windowTitles = Dictionary(
                uniqueKeysWithValues: windows.compactMap { window in
                    guard let processID = window.owningApplication?.processID,
                        let title = window.title
                    else { return nil }
                    return (WindowID(processID: processID, windowID: window.windowID), title)
                }
            )
        } catch {
            logger.logError(error, context: "Failed to update window titles")
        }
    }
}
