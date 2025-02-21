/*
 Source/SourceManager.swift
 Overview

 Created by William Pierce on 12/10/24.

 Coordinates source window management operations including focus handling,
 filtering, and state observation across the application.
*/

import ScreenCaptureKit
import SwiftUI

struct FocusedWindow: Equatable {
    let windowID: CGWindowID
    let processID: pid_t
    let bundleID: String
    let title: String
    
    static let empty = FocusedWindow(windowID: 0, processID: 0, bundleID: "", title: "")
}

@MainActor
final class SourceManager: ObservableObject {
    // Dependencies
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var permissionManager: PermissionManager
    private let sourceServices: SourceServices = SourceServices.shared
    private let captureServices: CaptureServices = CaptureServices.shared
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
    
    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = frontmostAppObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
        try await permissionManager.ensurePermissions()
        return try await captureServices.getAvailableSources()
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

    // MARK: - Private Methods

    private func setupObservers() {
        // Set up source observers
        sourceServices.sourceObserver.addObserver(
            id: observerId,
            onFocusChanged: { [weak self] in await self?.updateFocusedSource() },
            onTitleChanged: { [weak self] in await self?.updateSourceTitles() }
        )

        // Observe workspace notifications
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.updateFocusedSource()
            }
        }

        // Observe window focus changes
        frontmostAppObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.updateFocusedSource()
            }
        }

        logger.info("Window observers configured successfully")
    }

    private func updateFocusedSource() async {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            logger.debug("No active application found")
            focusedWindow = .empty
            return
        }

        let processID = activeApp.processIdentifier
        let bundleID = activeApp.bundleIdentifier ?? ""
        isOverviewActive = bundleID == Bundle.main.bundleIdentifier

        // Get window info efficiently
        if let (windowID, title) = await getWindowInfo(for: processID) {
            let newFocusedWindow = FocusedWindow(
                windowID: windowID,
                processID: processID,
                bundleID: bundleID,
                title: title
            )
            
            // Only trigger updates if focus actually changed
            if newFocusedWindow != focusedWindow {
                focusedWindow = newFocusedWindow
                objectWillChange.send()
                logger.debug("Focus state updated: bundleId=\(bundleID), title=\(title)")
            }
        }
    }
    
    private func getWindowInfo(for pid: pid_t) async -> (CGWindowID, String)? {
        let appElement = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        
        // Get the focused window
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &windowRef
        ) == .success else {
            return nil
        }
        
        let windowElement = windowRef as! AXUIElement
        
        // Get window title
        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            windowElement,
            kAXTitleAttribute as CFString,
            &titleRef
        ) == .success,
        let title = titleRef as? String else {
            return nil
        }

        // Get window ID
        var windowID: CGWindowID = 0
        typealias GetWindowFunc = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
        let frameworkHandle = dlopen(
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices",
            RTLD_NOW
        )
        defer { dlclose(frameworkHandle) }
        
        guard let windowSymbol = dlsym(frameworkHandle, "_AXUIElementGetWindow") else {
            return nil
        }
        
        let retrieveWindowIDFunction = unsafeBitCast(windowSymbol, to: GetWindowFunc.self)
        guard retrieveWindowIDFunction(windowElement, &windowID) == .success else {
            return nil
        }
        
        return (windowID, title)
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
