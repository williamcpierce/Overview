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
    private let captureServices = CaptureServices.shared
    private let sourceFilter: SourceFilterService
    private var sourceFocus: SourceFocusService!
    private let sourceObserver: SourceObserverService
    private let sourceInfo: SourceInfoService
    private let logger = AppLogger.sources
    private let axService: SourceAXService

    // Published State
    @Published private(set) var focusedWindow: FocusedWindow? = nil
    @Published private(set) var isOverviewActive: Bool = true
    @Published private(set) var sourceTitles: [SourceID: String] = [:]
    var persistentAXElements: [AXUIElement] {
        axService.axElements
    }

    // Private State
    private let observerId = UUID()
    private var workspaceObserver: NSObjectProtocol?
    private var frontmostAppObserver: NSObjectProtocol?

    // Source Settings
    @AppStorage(SourceSettingsKeys.filterMode)
    private var filterMode = SourceSettingsKeys.defaults.filterMode

    // MARK: - Source Identifier
    struct SourceID: Hashable {
        let processID: pid_t
        let windowID: CGWindowID
    }

    // MARK: - Initializer
    init(settingsManager: SettingsManager, permissionManager: PermissionManager) {
        self.settingsManager = settingsManager
        self.permissionManager = permissionManager
        self.sourceFilter = SourceFilterService()
        self.sourceObserver = SourceObserverService()
        self.sourceInfo = SourceInfoService()
        self.axService = SourceAXService()

        // Initialize sourceFocus after all other properties
        self.sourceFocus = SourceFocusService(sourceManager: self)

        setupObservers()
        initializeAXTracking()
        logger.debug("SourceManager initialized")
    }

    deinit {
        Task { await removeObservers() }
    }

    // MARK: - Public Methods

    func initializeAXTracking() {
        logger.info("Initializing AXUIElement tracking")
        axService.updateElementsForCurrentSpace()
        logger.info(
            "Initial AXUIElement tracking complete - \(persistentAXElements.count) elements collected"
        )
    }

    func focusSource(_ source: SCWindow) {
        logger.debug("Focusing source: \(source.title ?? "untitled")")
        sourceFocus.focusSource(source: source) { [weak self] in
            guard let self = self else { return }
            self.focusedWindow = FocusedWindow(
                windowID: source.windowID,
                processID: source.owningApplication?.processID ?? 0,
                bundleID: source.owningApplication?.bundleIdentifier ?? "",
                title: source.title ?? ""
            )
        }
    }

    func focusSource(withTitle title: String) -> Bool {
        logger.debug("Focusing source by title: \(title)")
        let success = sourceFocus.focusSource(withTitle: title) { [weak self] in
            self?.updateFocusedSource()
        }
        if !success { logger.error("Failed to focus: \(title)") }
        return success
    }

    func getAvailableSources() async throws -> [SCWindow] {
        try await permissionManager.ensurePermissions()
        return try await captureServices.getAvailableSources()
    }

    func getFilteredSources() async throws -> [SCWindow] {
        guard permissionManager.permissionStatus == .granted else {
            logger.warning("Permission not granted for source retrieval")
            return []
        }
        logger.debug("Retrieving filtered sources")
        let sources = try await captureServices.getAvailableSources()
        return sourceFilter.filterSources(
            sources,
            appFilterNames: settingsManager.filterAppNames,
            isFilterBlocklist: filterMode == FilterMode.blocklist
        )
    }

    // MARK: - Private Methods

    private func setupObservers() {
        sourceObserver.addObserver(
            id: observerId,
            onFocusChanged: updateFocusedSource,
            onTitleChanged: updateSourceTitles
        )
        observeWorkspaceChanges()
    }

    private func observeWorkspaceChanges() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateFocusedSource()
            }
        }

        frontmostAppObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateFocusedSource()
            }
        }
    }

    private func removeObservers() {
        [workspaceObserver, frontmostAppObserver].compactMap { $0 }.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        sourceObserver.removeObserver(id: observerId)
    }

    private func updateFocusedSource() {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            logger.debug("No active application")
            focusedWindow = nil
            return
        }

        isOverviewActive = activeApp.bundleIdentifier == Bundle.main.bundleIdentifier
        if let newFocusedWindow = getActiveWindow(for: activeApp) {
            if newFocusedWindow != focusedWindow {
                focusedWindow = newFocusedWindow
                logger.debug("Focus updated: \(newFocusedWindow.title)")
            }
        }
    }

    private func getActiveWindow(for app: NSRunningApplication) -> FocusedWindow? {
        let processID: pid_t = app.processIdentifier
        let bundleID: String = app.bundleIdentifier ?? ""
        if let (windowID, title) = sourceInfo.getWindowInfo(for: processID) {
            return FocusedWindow(
                windowID: windowID, processID: processID, bundleID: bundleID, title: title)
        }
        return nil
    }

    private func updateSourceTitles() async {
        guard permissionManager.permissionStatus == .granted else {
            logger.warning("Permission not granted for updating titles")
            return
        }
        do {
            let sources = try await captureServices.getAvailableSources()
            sourceTitles = Dictionary(
                uniqueKeysWithValues: sources.compactMap {
                    guard let processID = $0.owningApplication?.processID, let title = $0.title
                    else { return nil }
                    return (SourceID(processID: processID, windowID: $0.windowID), title)
                })
        } catch {
            logger.logError(error, context: "Failed updating source titles")
        }
    }
}

// MARK: - Focused Window Model

struct FocusedWindow: Equatable {
    let windowID: CGWindowID
    let processID: pid_t
    let bundleID: String
    let title: String
}
