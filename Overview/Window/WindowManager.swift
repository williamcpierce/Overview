/*
 Window/WindowManager.swift
 Overview

 Created by William Pierce on 12/10/24.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class WindowManager: ObservableObject {
    // MARK: - Published State
    @Published private(set) var focusedBundleId: String?
    @Published private(set) var focusedProcessId: pid_t?
    @Published private(set) var isOverviewActive: Bool = true
    @Published private(set) var windowTitles: [WindowID: String] = [:]

    // MARK: - Dependencies
    private let windowServices: WindowServices = WindowServices.shared
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

    func focusWindow(_ window: SCWindow) {
        windowServices.windowFocus.focusWindow(window: window)
    }

    func focusWindow(withTitle title: String) -> Bool {
        let success = windowServices.windowFocus.focusWindow(withTitle: title)
        if !success {
            logger.error("Failed to activate window: '\(title)'")
        }
        return success
    }

    private func setupObservers() {
        windowServices.windowObserver.addObserver(
            id: observerId,
            onFocusChanged: { [weak self] in await self?.updateFocusedWindow() },
            onTitleChanged: { [weak self] in await self?.updateWindowTitles() }
        )
    }

    private func updateFocusedWindow() async {
        guard let activeApp: NSRunningApplication = NSWorkspace.shared.frontmostApplication else {
            return
        }
        focusedProcessId = activeApp.processIdentifier
        focusedBundleId = activeApp.bundleIdentifier
        isOverviewActive = activeApp.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    private func updateWindowTitles() async {
        do {
            let windows = try await captureServices.getAvailableWindows()
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

    func getFilteredWindows() async throws -> [SCWindow] {
        let availableWindows = try await captureServices.getAvailableWindows()
        let filteredWindows = windowServices.windowFilter.filterWindows(availableWindows)
        return filteredWindows
    }
}
