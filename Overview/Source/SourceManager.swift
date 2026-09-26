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

        focusedProcessId = resolveFocusedProcessId(for: activeApp)
        focusedBundleId = activeApp.bundleIdentifier
        isOverviewActive = activeApp.bundleIdentifier == Bundle.main.bundleIdentifier

        logger.debug("Focus state updated: bundleId=\(activeApp.bundleIdentifier ?? "unknown")")
    }

    /// Resolves the process identifier of the frontmost application.
    ///
    /// `NSWorkspace` reports a process identifier of -1 for some applications on
    /// macOS 27, while still reporting their bundle identifier. Applications
    /// launched from outside the standard locations, such as the EVE clients in
    /// Application Support, are affected. For those, fall back to asking each
    /// known source process whether it is active, which is still reported
    /// correctly, and which distinguishes between multiple processes of the same
    /// application where the bundle identifier cannot.
    private func resolveFocusedProcessId(for activeApp: NSRunningApplication) -> pid_t? {
        let reportedProcessId = activeApp.processIdentifier

        guard reportedProcessId == -1 else { return reportedProcessId }

        let candidates = Set(sourceTitles.keys.map(\.processID))
        let activeProcessId = candidates.first { candidate in
            NSRunningApplication(processIdentifier: candidate)?.isActive == true
        }

        if let activeProcessId {
            logger.debug("Recovered focused process ID by activity: \(activeProcessId)")
        } else {
            logger.debug("No active source process found for \(activeApp.bundleIdentifier ?? "unknown")")
        }

        return activeProcessId
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
