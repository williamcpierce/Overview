/*
 Source/SourceManager.swift
 Overview

 Created by William Pierce on 12/10/24.

 Coordinates source window management operations including focus handling,
 filtering, and state observation across the application.
*/

import Defaults
import ScreenCaptureKit
import SwiftUI

@MainActor
final class SourceManager: ObservableObject {
    // Dependencies
    @ObservedObject var permissionManager: PermissionManager
    private let sourceServices: SourceServices = SourceServices.shared
    private let captureServices: CaptureServices = CaptureServices.shared
    private let logger = AppLogger.sources

    // Published State
    @Published private(set) var focusedBundleId: String?
    @Published private(set) var focusedProcessId: pid_t?
    @Published private(set) var isOverviewActive: Bool = true
    @Published private(set) var sourceTitles: [SourceID: String] = [:]

    // Private State
    private let observerId = UUID()

    // Type Definitions
    struct SourceID: Hashable {
        let processID: pid_t
        let windowID: CGWindowID
    }

    init(permissionManager: PermissionManager) {
        self.permissionManager = permissionManager
        setupObservers()
        logger.debug("Source window manager initialization complete")
    }

    // MARK: - Public Methods

    func focusSource(_ source: SCWindow) {
        logger.debug("Processing source window focus request: '\(source.title ?? "untitled")'")
        sourceServices.focusSource(source)
    }

    func focusSource(withTitle title: String) -> Bool {
        logger.debug("Processing title-based focus request: '\(title)'")
        let success = sourceServices.focusSource(withTitle: title)

        if !success {
            logger.error("Failed to focus source window: '\(title)'")
        }

        return success
    }

    func getAvailableSources() async throws -> [SCWindow] {
        try await permissionManager.ensurePermission()
        let availableSources = try await CaptureServices.shared.getAvailableSources()
        return availableSources
    }

    func getFilteredSources() async throws -> [SCWindow] {
        if permissionManager.permissionStatus != .granted {
            logger.debug("Skipping source retrieval: permission not granted")
            return []
        }

        logger.debug("Retrieving filtered window list")
        let availableSources = try await captureServices.getAvailableSources()

        let filteredSources = sourceServices.filterSources(
            availableSources,
            appFilterNames: Defaults[.appFilterNames],
            isFilterBlocklist: Defaults[.filterMode] == FilterMode.blocklist
        )

        logger.info("Retrieved \(filteredSources.count) filtered source windows")
        return filteredSources
    }

    // Reacquires a previously bound source window from the live window list.
    // Matches the saved window ID first (exact window within the current
    // session), then falls back to title, optionally constrained to the
    // same owning application. Returns nil when no live window matches.
    func findSource(matching saved: WindowSource) async -> SCWindow? {
        guard let title: String = saved.title, !title.isEmpty else {
            return nil
        }

        let candidates: [SCWindow]
        do {
            candidates = try await getFilteredSources()
        } catch {
            logger.logError(error, context: "Failed to retrieve sources for layout restore")
            return nil
        }

        if let windowID: UInt32 = saved.windowID,
            let exactMatch = candidates.first(where: {
                $0.windowID == windowID && $0.title == title
            })
        {
            return exactMatch
        }

        if let windowID: UInt32 = saved.windowID,
            let sameAppMatch = candidates.first(where: {
                $0.windowID == windowID && $0.owningApplication?.bundleIdentifier
                    == saved.bundleID
            })
        {
            return sameAppMatch
        }

        if let bundleID: String = saved.bundleID,
            let titledAppMatch = candidates.first(where: {
                $0.title == title && $0.owningApplication?.bundleIdentifier == bundleID
            })
        {
            return titledAppMatch
        }

        let titleMatch = candidates.first(where: { $0.title == title })

        if titleMatch == nil {
            logger.debug("No live window found matching saved source title: '\(title)'")
        }

        return titleMatch
    }

    // MARK: - Private Methods

    private func setupObservers() {
        sourceServices.sourceObserver.addObserver(
            id: observerId,
            onFocusChanged: { [weak self] in await self?.updateFocusedSource() },
            onTitleChanged: { [weak self] in await self?.updateSourceTitles() }
        )

        logger.info("Window observers configured successfully")
    }

    private func updateFocusedSource() async {
        guard let activeApp: NSRunningApplication = NSWorkspace.shared.frontmostApplication else {
            logger.debug("No active application found")
            return
        }

        focusedProcessId = activeApp.processIdentifier
        focusedBundleId = activeApp.bundleIdentifier
        isOverviewActive = activeApp.bundleIdentifier == Bundle.main.bundleIdentifier

        logger.debug("Focus state updated: bundleId=\(activeApp.bundleIdentifier ?? "unknown")")
    }

    private func updateSourceTitles() async {
        if permissionManager.permissionStatus != .granted {
            logger.debug("Skipping title update: permission not granted")
            return
        }

        do {
            let sources = try await captureServices.getAvailableSources()
            sourceTitles = Dictionary(
                uniqueKeysWithValues: sources.compactMap { source in
                    guard let processID = source.owningApplication?.processID,
                        let title = source.title
                    else { return nil }
                    return (SourceID(processID: processID, windowID: source.windowID), title)
                }
            )
        } catch {
            logger.logError(error, context: "Failed to update source window titles")
        }
    }
}
