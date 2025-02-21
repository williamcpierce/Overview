/*
 Source/SourceManager.swift
 Overview

 Created by William Pierce on 12/10/24.

 Coordinates source window management operations including focus handling,
 filtering, and state observation across the application.
*/

import ScreenCaptureKit
import SwiftUI

// MARK: - Focused Window Model
struct FocusedWindow: Equatable {
    let windowID: CGWindowID
    let processID: pid_t
    let bundleID: String
    let title: String

    static let empty = FocusedWindow(windowID: 0, processID: 0, bundleID: "", title: "")
}

// MARK: - Source Manager
@MainActor
final class SourceManager: ObservableObject {
    // Dependencies
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var permissionManager: PermissionManager
    private let captureServices = CaptureServices.shared
    private let sourceFilter = SourceFilterService()
    private let sourceFocus = SourceFocusService()
    private let sourceObserver = SourceObserverService()
    private let logger = AppLogger.sources

    // Published State
    @Published private(set) var focusedWindow: FocusedWindow = .empty
    @Published private(set) var isOverviewActive: Bool = true
    @Published private(set) var sourceTitles: [SourceID: String] = [:]

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
        setupObservers()
        logger.debug("SourceManager initialized")
    }

    deinit {
        Task { await removeObservers() }
    }

    // MARK: - Public Methods

    func focusSource(_ source: SCWindow) {
        logger.debug("Focusing source: \(source.title ?? "untitled")")
        sourceFocus.focusSource(source: source) { [weak self] in
            guard let self = self else { return }

            // Immediately update the focused window state
            let processID = source.owningApplication?.processID ?? 0
            let bundleID = source.owningApplication?.bundleIdentifier ?? ""
            let newFocusedWindow = FocusedWindow(
                windowID: source.windowID,
                processID: processID,
                bundleID: bundleID,
                title: source.title ?? ""
            )
            self.focusedWindow = newFocusedWindow
        }
    }

    func focusSource(withTitle title: String) -> Bool {
        logger.debug("Focusing source by title: \(title)")
        let success = sourceFocus.focusSource(withTitle: title) { [weak self] in
            guard let self = self else { return }

            // Immediately update the focused window state.
            self.updateFocusedSource()
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
            logger.debug("Permission not granted for source retrieval")
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
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = frontmostAppObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        sourceObserver.removeObserver(id: observerId)
    }

    private func updateFocusedSource() {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            logger.debug("No active application")
            focusedWindow = .empty
            return
        }

        let processID = activeApp.processIdentifier
        let bundleID = activeApp.bundleIdentifier ?? ""
        isOverviewActive = bundleID == Bundle.main.bundleIdentifier

        if let (windowID, title) = getWindowInfo(for: processID) {
            let newFocusedWindow = FocusedWindow(
                windowID: windowID,
                processID: processID,
                bundleID: bundleID,
                title: title
            )
            if newFocusedWindow != focusedWindow {
                focusedWindow = newFocusedWindow
                logger.debug("Focus updated: \(title)")
            }
        }
    }

    private func getWindowInfo(for pid: pid_t) -> (CGWindowID, String)? {
        let appElement = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success
        else { return nil }

        let windowElement = unsafeBitCast(windowRef, to: AXUIElement.self)

        var titleRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef)
                == .success,
            let title = titleRef as? String
        else { return nil }

        return (WindowIDUtility.extractWindowID(from: windowElement), title)
    }

    private func updateSourceTitles() async {
        guard permissionManager.permissionStatus == .granted else {
            logger.debug("Permission not granted for updating titles")
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
                })
        } catch {
            logger.logError(error, context: "Failed updating source titles")
        }
    }
}

// MARK: - Window ID Utility

enum WindowIDUtility {
    /// Extracts the window ID from an Accessibility UI Element
    static func extractWindowID(from window: AXUIElement) -> CGWindowID {
        var windowID: CGWindowID = 0

        // Retrieve window ID from AXUIElement using ApplicationServices framework
        typealias GetWindowFunc = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) ->
            AXError
        let frameworkHandle = dlopen(
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices",
            RTLD_NOW
        )
        let windowSymbol = dlsym(frameworkHandle, "_AXUIElementGetWindow")
        let retrieveWindowIDFunction = unsafeBitCast(windowSymbol, to: GetWindowFunc.self)
        _ = retrieveWindowIDFunction(window, &windowID)
        dlclose(frameworkHandle)

        return windowID
    }
}
