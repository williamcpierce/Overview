/*
 Window/WindowManager.swift
 Overview

 Created by William Pierce on 12/10/24.

 Coordinates window management operations including focus handling,
 window filtering, and state observation across the application.
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

    private let appSettings: AppSettings
    private let windowServices: WindowServices = WindowServices.shared
    private let captureServices: CaptureServices = CaptureServices.shared
    private let logger = AppLogger.windows
    private let observerId = UUID()

    // MARK: - Types

    struct WindowID: Hashable {
        let processID: pid_t
        let windowID: CGWindowID
    }

    // MARK: - Initialization

    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        logger.debug("Initializing window manager")
        setupObservers()
        logger.info("Window manager initialization complete")
    }

    // MARK: - Public Interface

    func focusWindow(_ window: SCWindow) {
        logger.debug("Processing window focus request: '\(window.title ?? "untitled")'")
        windowServices.windowFocus.focusWindow(window: window)
    }

    func focusWindow(withTitle title: String) -> Bool {
        logger.debug("Processing title-based focus request: '\(title)'")
        let success = windowServices.windowFocus.focusWindow(withTitle: title)

        if !success {
            logger.error("Failed to focus window: '\(title)'")
        }

        return success
    }

    func getFilteredWindows() async throws -> [SCWindow] {
        logger.debug("Retrieving filtered window list")

        let availableWindows = try await captureServices.getAvailableWindows()
        let filteredWindows = windowServices.windowFilter.filterWindows(
            availableWindows,
            appFilterNames: appSettings.appFilterNames,
            isFilterBlocklist: appSettings.isFilterBlocklist
        )

        logger.info("Retrieved \(filteredWindows.count) filtered windows")
        return filteredWindows
    }

    // MARK: - Private Methods

    private func setupObservers() {
        logger.debug("Configuring window state observers")

        windowServices.windowObserver.addObserver(
            id: observerId,
            onFocusChanged: { [weak self] in await self?.updateFocusedWindow() },
            onTitleChanged: { [weak self] in await self?.updateWindowTitles() }
        )

        logger.info("Window observers configured successfully")
    }

    private func updateFocusedWindow() async {
        guard let activeApp: NSRunningApplication = NSWorkspace.shared.frontmostApplication else {
            logger.debug("No active application found")
            return
        }

        focusedProcessId = activeApp.processIdentifier
        focusedBundleId = activeApp.bundleIdentifier
        isOverviewActive = activeApp.bundleIdentifier == Bundle.main.bundleIdentifier

        logger.debug("Focus state updated: bundleId=\(activeApp.bundleIdentifier ?? "unknown")")
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
            logger.debug("Window titles updated: count=\(windowTitles.count)")
        } catch {
            logger.logError(error, context: "Failed to update window titles")
        }
    }
}
