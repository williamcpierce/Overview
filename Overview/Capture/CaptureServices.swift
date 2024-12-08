/*
 CaptureServices.swift
 Overview

 Created by William Pierce on 12/6/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import OSLog
import ScreenCaptureKit

// MARK: - Stream Configuration Service
class StreamConfigurationService {
    func createConfiguration(_ window: SCWindow, frameRate: Double) -> (
        SCStreamConfiguration, SCContentFilter
    ) {
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.queueDepth = 3
        config.showsCursor = false

        let filter = SCContentFilter(desktopIndependentWindow: window)
        return (config, filter)
    }

    func updateConfiguration(_ stream: SCStream?, _ window: SCWindow, frameRate: Double)
        async throws
    {
        guard let stream = stream else { return }
        let (config, filter) = createConfiguration(window, frameRate: frameRate)
        try await stream.updateConfiguration(config)
        try await stream.updateContentFilter(filter)
    }
}

// MARK: - Window Filter Service
class WindowFilterService {
    private let systemAppBundleIDs = ["com.apple.controlcenter", "com.apple.notificationcenterui"]

    func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        windows.filter { window in
            isValidBasicWindow(window) && isNotSystemWindow(window)
        }
    }

    private func isValidBasicWindow(_ window: SCWindow) -> Bool {
        window.isOnScreen && window.frame.height > 100
            && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            && window.windowLayer == 0 && window.title != nil && !window.title!.isEmpty
    }

    private func isNotSystemWindow(_ window: SCWindow) -> Bool {
        let isNotDesktop =
            window.owningApplication?.bundleIdentifier != "com.apple.finder"
            || window.title != "Desktop"
        let isNotSystemUIServer =
            window.owningApplication?.bundleIdentifier != "com.apple.systemuiserver"
        let isNotSystemApp = !systemAppBundleIDs.contains(
            window.owningApplication?.bundleIdentifier ?? "")
        return isNotDesktop && isNotSystemUIServer && isNotSystemApp
    }
}

// MARK: - Window Focus Service
class WindowFocusService {
    func focusWindow(window: SCWindow, isEditModeEnabled: Bool) {
        guard !isEditModeEnabled,
            let processID = window.owningApplication?.processID
        else { return }

        NSRunningApplication(processIdentifier: pid_t(processID))?
            .activate()
    }

    func updateFocusState(for window: SCWindow?) async -> Bool {
        guard let window = window,
            let activeApp = NSWorkspace.shared.frontmostApplication,
            let selectedApp = window.owningApplication
        else { return false }

        return activeApp.processIdentifier == selectedApp.processID
    }
}

// MARK: - Window Title Service
class WindowTitleService {
    private let logger = Logger(
        subsystem: "com.Overview.WindowTitleService", category: "WindowTitle")

    func updateWindowTitle(for window: SCWindow?) async -> String? {
        guard let window = window else { return nil }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)
            return content.windows.first { updatedWindow in
                updatedWindow.owningApplication?.processID == window.owningApplication?.processID
                    && updatedWindow.frame == window.frame
            }?.title
        } catch {
            logger.error("Failed to update window title: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Window Observer Service
class WindowObserverService {
    var onFocusStateChanged: (() async -> Void)?
    var onWindowTitleChanged: (() async -> Void)?

    private var workspaceObserver: NSObjectProtocol?
    private var windowObserver: NSObjectProtocol?
    private var titleCheckTimer: Timer?

    deinit {
        stopObserving()
    }

    func startObserving() {
        setupWorkspaceObserver()
        setupWindowObserver()
        startTitleChecks()
    }

    func stopObserving() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        titleCheckTimer?.invalidate()
    }

    private func setupWorkspaceObserver() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.onFocusStateChanged?()
            }
        }
    }

    private func setupWindowObserver() {
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.onFocusStateChanged?()
            }
        }
    }

    private func startTitleChecks() {
        titleCheckTimer?.invalidate()
        titleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { [weak self] in
                await self?.onWindowTitleChanged?()
            }
        }
    }
}

// MARK: - Shareable Content Service
class ShareableContentService {
    func requestPermission() async throws {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }

    func getAvailableWindows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        return content.windows
    }
}
