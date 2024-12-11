/*
 WindowManager.swift
 Overview

 Created by William Pierce on 12/10/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import OSLog
import ScreenCaptureKit

@MainActor
final class WindowManager {
    static let shared = WindowManager()

    struct WindowState: Equatable {
        let window: SCWindow
        var isFocused: Bool
        var title: String
        let processID: pid_t
        let frame: CGRect

        init(window: SCWindow, isFocused: Bool, title: String) {
            self.window = window
            self.isFocused = isFocused
            self.title = title
            self.processID = window.owningApplication?.processID ?? 0
            self.frame = window.frame
        }
    }

    private let logger = Logger(
        subsystem: "com.Overview.WindowManager", category: "WindowManagement")
    private let shareableContent = ShareableContentService()
    private var trackedWindows: [String: WindowState] = [:]
    private var windowUpdateTimer: Timer?

    private let systemAppBundleIDs = [
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
    ]

    private init() {
        startWindowTracking()
    }

    func getAvailableWindows() async -> [SCWindow] {
        await updateWindowState()
        return Array(trackedWindows.values.map { $0.window })
    }

    func findWindow(withTitle title: String) -> SCWindow? {
        trackedWindows[title]?.window
    }

    @discardableResult
    func focusWindow(withTitle title: String) -> Bool {
        guard let windowState = trackedWindows[title],
            let processID = windowState.window.owningApplication?.processID
        else {
            logger.error("No window found with title: \(title)")
            return false
        }

        logger.info("Focusing window: \(title) with processID: \(processID)")
        return NSRunningApplication(processIdentifier: pid_t(processID))?.activate() ?? false
    }

    func isWindowFocused(_ window: SCWindow) -> Bool {
        guard let title = window.title else { return false }
        return trackedWindows[title]?.isFocused ?? false
    }

    func updateWindowState() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)
            let filteredWindows = filterWindows(content.windows)
            let activeApp = NSWorkspace.shared.frontmostApplication
            let activeProcessID = activeApp?.processIdentifier

            logger.debug("Active app processID: \(String(describing: activeProcessID))")

            var newTrackedWindows: [String: WindowState] = [:]

            for window in filteredWindows {
                guard let processID = window.owningApplication?.processID,
                    let title = window.title
                else { continue }

                let isFocused = processID == activeProcessID
                logger.debug("Window '\(title)' processID: \(processID), isFocused: \(isFocused)")
                newTrackedWindows[title] = WindowState(
                    window: window, isFocused: isFocused, title: title)
            }

            trackedWindows = newTrackedWindows

        } catch {
            logger.error("Failed to update window state: \(error.localizedDescription)")
        }
    }

    func subscribeToWindowState(_ window: SCWindow, onUpdate: @escaping (Bool, String?) -> Void) {
        guard let processID = window.owningApplication?.processID else { return }
        let frame = window.frame
        let windowTitle = window.title

        logger.debug(
            "Setting up subscription for window: \(windowTitle ?? "unknown"), processID: \(processID)"
        )

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let currentlyActive = NSWorkspace.shared.frontmostApplication?.processIdentifier
                let isFocused = processID == currentlyActive

                if let state = self.trackedWindows.values.first(where: { state in
                    state.processID == processID && state.frame == frame
                }) {
                    logger.debug(
                        "Window '\(state.title)' status - focused: \(isFocused), active app: \(String(describing: currentlyActive))"
                    )
                    onUpdate(isFocused, state.title)
                }
            }
        }
    }

    private func startWindowTracking() {
        windowUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateWindowState()
            }
        }
    }

    private func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        windows.filter { window in
            isValidWindow(window) && !isSystemWindow(window)
        }
    }

    private func isValidWindow(_ window: SCWindow) -> Bool {
        window.isOnScreen && window.frame.height > 100
            && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            && window.windowLayer == 0 && window.title != nil && !window.title!.isEmpty
    }

    private func isSystemWindow(_ window: SCWindow) -> Bool {
        let isDesktop =
            window.owningApplication?.bundleIdentifier == "com.apple.finder"
            && window.title == "Desktop"
        let isSystemUI = window.owningApplication?.bundleIdentifier == "com.apple.systemuiserver"
        let isSystemApp = systemAppBundleIDs.contains(
            window.owningApplication?.bundleIdentifier ?? "")

        return isDesktop || isSystemUI || isSystemApp
    }

    deinit {
        windowUpdateTimer?.invalidate()
    }
}
