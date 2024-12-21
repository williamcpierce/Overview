/*
 Window/WindowManager.swift
 Overview

 Created by William Pierce on 12/10/24.

 Provides centralized window management operations across the application, serving as
 the single source of truth for window state tracking and focus operations. Manages
 window caching and periodic updates to ensure efficient window lookup with minimal
 system overhead.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class WindowManager: ObservableObject {

    private let windowServices = WindowServices.shared
    private let contentService = ShareableContentService.shared

    private var titleToWindowMap: [String: SCWindow] = [:]
    private var cacheSyncTimer: Timer?

    init() {
        setupPeriodicCacheSync()
    }

    func getFilteredWindows() async -> [SCWindow] {
        do {
            let systemWindows = try await contentService.getAvailableWindows()
            let filteredWindows = windowServices.windowFilter.filterWindows(systemWindows)
            synchronizeTitleCache(with: filteredWindows)
            return filteredWindows
        } catch {
            AppLogger.windows.logError(
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
            AppLogger.windows.error("Failed to activate window process: '\(title)'")
        }
        return success
    }

    private func setupPeriodicCacheSync() {
        cacheSyncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                _ = await self?.getFilteredWindows()
            }
        }
    }

    private func synchronizeTitleCache(with windows: [SCWindow]) {
        titleToWindowMap.removeAll()
        windows.forEach { window in
            if let title = window.title {
                titleToWindowMap[title] = window
            }
        }
    }

    deinit {
        cacheSyncTimer?.invalidate()
    }
}
