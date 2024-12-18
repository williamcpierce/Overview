/*
 WindowServices.swift
 Overview

 Created by William Pierce on 12/15/24.

 Provides a service-oriented architecture for window management, offering a set of
 specialized services for window filtering, focusing, title tracking, and state
 observation through a centralized singleton container.
*/

import AppKit
import ScreenCaptureKit

/// Centralizes window management functionality through domain-specific services
@MainActor
final class WindowServices {
    static let shared = WindowServices()

    let windowFilter = WindowFilterService()
    let windowFocus = WindowFocusService()
    let titleService = WindowTitleService()
    let windowObserver = WindowObserverService()
    let shareableContent = ShareableContentService()

    private init() {
        AppLogger.windows.info("Initializing window services container")
    }
}

final class WindowFilterService {
    private let logger = AppLogger.windows
    private let systemAppBundleIDs = Set([
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
    ])

    func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        logger.debug("Starting window filtering: total=\(windows.count)")
        let filtered = windows.filter { window in
            meetsBasicRequirements(window) && isNotSystemComponent(window)
        }
        logger.info(
            "Window filtering complete: valid=\(filtered.count), filtered=\(windows.count - filtered.count)"
        )
        return filtered
    }

    private func meetsBasicRequirements(_ window: SCWindow) -> Bool {
        let isValid =
            window.isOnScreen
            && window.frame.height > 100
            && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            && window.windowLayer == 0
            && window.title != nil
            && !window.title!.isEmpty

        if !isValid {
            logger.debug(
                "Window failed validation: '\(window.title ?? "untitled")', height=\(window.frame.height), layer=\(window.windowLayer)"
            )
        }
        return isValid
    }

    private func isNotSystemComponent(_ window: SCWindow) -> Bool {
        let isNotDesktopView =
            window.owningApplication?.bundleIdentifier != "com.apple.finder"
            || window.title != "Desktop"

        let isNotSystemUI =
            window.owningApplication?.bundleIdentifier != "com.apple.systemuiserver"

        let isNotSystemApp = !systemAppBundleIDs.contains(
            window.owningApplication?.bundleIdentifier ?? "")

        let isNotSystem = isNotDesktopView && isNotSystemUI && isNotSystemApp

        if !isNotSystem {
            logger.debug(
                "Excluding system window: '\(window.title ?? "untitled")', bundleID=\(window.owningApplication?.bundleIdentifier ?? "unknown")"
            )
        }

        return isNotSystem
    }
}

@MainActor
final class WindowFocusService {
    private let logger = AppLogger.windows

    func focusWindow(window: SCWindow, isEditModeEnabled: Bool) {
        guard !isEditModeEnabled,
            let processID = window.owningApplication?.processID
        else {
            logger.warning(
                "Focus request blocked: editMode=\(isEditModeEnabled), processID=\(window.owningApplication?.processID ?? 0)"
            )
            return
        }

        logger.debug("Focusing window: '\(window.title ?? "untitled")', processID=\(processID)")

        let success = activateProcess(processID)

        if success {
            logger.info("Window successfully focused: '\(window.title ?? "untitled")'")
        } else {
            logger.error("Window focus failed: processID=\(processID)")
        }
    }

    func focusWindow(withTitle title: String) -> Bool {
        logger.debug("Processing title-based focus request: '\(title)'")

        guard let runningApp = findApplication(forWindowTitle: title) else {
            logger.warning("No application found for window: '\(title)'")
            return false
        }

        NSApp.activate(ignoringOtherApps: true)
        let success = runningApp.activate()

        if success {
            logger.info("Title-based focus successful: '\(title)'")
        } else {
            logger.error("Title-based focus failed: '\(title)'")
        }

        return success
    }

    private func findApplication(forWindowTitle title: String) -> NSRunningApplication? {
        let options = CGWindowListOption(arrayLiteral: .optionAll)
        let windowList =
            CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] ?? []

        logger.debug("Searching \(windowList.count) windows for title match: '\(title)'")

        guard
            let windowInfo = windowList.first(where: { info in
                guard let windowTitle = info[kCGWindowName] as? String,
                    !windowTitle.isEmpty
                else { return false }
                return windowTitle == title
            }), let windowPID = windowInfo[kCGWindowOwnerPID] as? pid_t
        else {
            logger.warning("No matching window found: '\(title)'")
            return nil
        }

        let runningApp = NSWorkspace.shared.runningApplications.first { app in
            app.processIdentifier == windowPID
        }

        if let app = runningApp {
            logger.debug("Found application: '\(app.localizedName ?? "unknown")', pid=\(windowPID)")
        } else {
            logger.warning("No running application for pid=\(windowPID)")
        }

        return runningApp
    }

    private func activateProcess(_ processID: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: processID) else {
            logger.error("Invalid process ID: \(processID)")
            return false
        }
        return app.activate()
    }

    func updateFocusState(for window: SCWindow?) async -> Bool {
        guard let window = window,
            let activeApp = NSWorkspace.shared.frontmostApplication,
            let selectedApp = window.owningApplication
        else {
            logger.debug("Focus state check failed: missing window or app reference")
            return false
        }

        let isFocused = activeApp.processIdentifier == selectedApp.processID

        if isFocused {
            logger.debug("Window is focused: '\(window.title ?? "untitled")'")
        }

        return isFocused
    }
}

final class WindowTitleService {
    private let logger = AppLogger.windows

    func updateWindowTitle(for window: SCWindow?) async -> String? {
        guard let window = window else {
            logger.debug("Title update skipped: nil window reference")
            return nil
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: false)

            let title = content.windows.first { updatedWindow in
                updatedWindow.owningApplication?.processID == window.owningApplication?.processID
                    && updatedWindow.windowID == window.windowID
            }?.title

            if let title = title {
                logger.debug("Title updated: '\(title)'")
            } else {
                logger.warning("No matching window found for title update")
            }

            return title
        } catch {
            logger.error("Title update failed: \(error.localizedDescription)")
            return nil
        }
    }
}

final class WindowObserverService {
    private let logger = AppLogger.windows
    private var focusObservers: [UUID: () async -> Void] = [:]
    private var titleObservers: [UUID: () async -> Void] = [:]
    private var workspaceObserver: NSObjectProtocol?
    private var windowObserver: NSObjectProtocol?
    private var titleCheckTimer: Timer?

    deinit {
        stopObserving()
    }

    func addObserver(
        id: UUID,
        onFocusChanged: @escaping () async -> Void,
        onTitleChanged: @escaping () async -> Void
    ) {
        logger.debug("Adding state observer: \(id)")

        focusObservers[id] = onFocusChanged
        titleObservers[id] = onTitleChanged

        if focusObservers.count == 1 {
            startObserving()
        }
    }

    func removeObserver(id: UUID) {
        logger.debug("Removing state observer: \(id)")
        focusObservers.removeValue(forKey: id)
        titleObservers.removeValue(forKey: id)

        if focusObservers.isEmpty {
            stopObserving()
        }
    }

    private func startObserving() {
        logger.info("Starting window state observation")
        setupWorkspaceObserver()
        setupWindowObserver()
        startTitleChecks()
    }

    private func stopObserving() {
        logger.info("Stopping window state observation")

        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        titleCheckTimer?.invalidate()
    }

    private func setupWorkspaceObserver() {
        logger.debug("Configuring workspace observer")

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.focusObservers else { return }
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }

    private func setupWindowObserver() {
        logger.debug("Configuring window observer")

        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.focusObservers else { return }
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }

    private func startTitleChecks() {
        titleCheckTimer?.invalidate()
        logger.debug("Starting title check timer")

        titleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { [weak self] in
                guard let observers = self?.titleObservers else { return }
                for callback in observers.values {
                    await callback()
                }
            }
        }
    }
}

final class ShareableContentService {
    private let logger = AppLogger.capture

    func requestPermission() async throws {
        logger.info("Requesting screen recording permission")

        do {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            logger.info("Screen recording permission granted")
        } catch {
            logger.error("Screen recording permission denied: \(error.localizedDescription)")
            throw CaptureError.permissionDenied
        }
    }

    func getAvailableWindows() async throws -> [SCWindow] {
        logger.debug("Fetching available windows")

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)

            logger.info("Retrieved \(content.windows.count) available windows")
            return content.windows
        } catch {
            logger.error("Failed to get windows: \(error.localizedDescription)")
            throw error
        }
    }
}
