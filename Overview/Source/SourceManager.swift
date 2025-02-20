/*
 Source/SourceManager.swift
 Overview

 Created by William Pierce on 12/10/24.

 Coordinates source window management operations including focus handling,
 filtering, and state observation across the application.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class SourceManager: ObservableObject {
    // Dependencies
    @ObservedObject var settingsManager: SettingsManager
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

    // Source Settings
    @AppStorage(SourceSettingsKeys.filterMode)
    private var filterMode = SourceSettingsKeys.defaults.filterMode

    // Type Definitions
    struct SourceID: Hashable {
        let processID: pid_t
        let windowID: CGWindowID
    }

    init(settingsManager: SettingsManager, permissionManager: PermissionManager) {
        self.settingsManager = settingsManager
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
            appFilterNames: settingsManager.filterAppNames,
            isFilterBlocklist: filterMode == FilterMode.blocklist
        )

        logger.info("Retrieved \(filteredSources.count) filtered source windows")
        return filteredSources
    }

    func getActiveWindowTitle() -> String? {
        guard !isOverviewActive else { return nil }

        guard
            let runningApps = NSWorkspace.shared.runningApplications.first(where: {
                $0.processIdentifier == focusedProcessId
            })
        else {
            logger.debug("No active application found")
            return nil
        }

        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
        let windowList =
            CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] ?? []

        let activeWindowInfo = windowList.first { info in
            guard let pid = info[kCGWindowOwnerPID] as? pid_t,
                pid == runningApps.processIdentifier,
                let layer = info[kCGWindowLayer] as? Int,
                layer == 0,
                let title = info[kCGWindowName] as? String,
                !title.isEmpty
            else { return false }
            return true
        }

        return activeWindowInfo?[kCGWindowName] as? String
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
