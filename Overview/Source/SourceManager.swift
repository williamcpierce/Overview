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
    @Published private(set) var focusedWindow: FocusedWindow? = nil
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
        if let (windowID, title) = getWindowInfo(for: processID) {
            return FocusedWindow(
                windowID: windowID, processID: processID, bundleID: bundleID, title: title)
        }
        return nil
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
                == .success, let title = titleRef as? String
        else { return nil }
        return (WindowIDUtility.extractWindowID(from: windowElement), title)
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
