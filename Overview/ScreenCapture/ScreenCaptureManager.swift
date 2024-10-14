/*
 ScreenCaptureManager.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import Foundation
import ScreenCaptureKit
import CoreImage
import AppKit
import Combine
import OSLog

@MainActor
class ScreenCaptureManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var capturedFrame: CapturedFrame?
    @Published var availableWindows: [SCWindow] = []
    @Published var selectedWindow: SCWindow?
    @Published var isCapturing = false

    // MARK: - Private Properties
    private var stream: SCStream?
    private let captureEngine = CaptureEngine()
    private var captureTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.Overview.ScreenCaptureManager", category: "ScreenCapture")
    private var appSettings: AppSettings

    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        super.init()
    }
    
    // MARK: - Public Methods
    /// Requests permission to capture the screen.
    func requestPermission() async -> Bool {
        do {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            logger.error("Failed to request screen capture permission: \(error.localizedDescription)")
            return false
        }
    }

    /// Updates the list of available windows for screen capture.
    func updateAvailableWindows() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            self.availableWindows = filterWindows(content.windows)
            logger.info("Available windows updated. Count: \(self.availableWindows.count)")
        } catch {
            logger.error("Failed to get available windows: \(error.localizedDescription)")
        }
    }

    /// Starts capturing the selected window.
    func startCapture() async {
        guard !isCapturing, let window = selectedWindow else {
            logger.warning("Cannot start capture: No window selected or already capturing.")
            return
        }

        captureTask?.cancel()

        let config = createStreamConfiguration(for: window)
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let frameStream = captureEngine.startCapture(configuration: config, filter: filter)

        isCapturing = true

        captureTask = Task {
            do {
                for try await frame in frameStream {
                    self.capturedFrame = frame
                }
            } catch {
                logger.error("Capture stream failed with error: \(error.localizedDescription)")
                isCapturing = false
            }
        }
    }

    /// Stops the ongoing capture.
    func stopCapture() async {
        guard isCapturing else {
            logger.warning("Cannot stop capture: Not currently capturing.")
            return
        }

        captureTask?.cancel()
        await captureEngine.stopCapture()

        isCapturing = false
        capturedFrame = nil
    }

    /// Brings the selected window to the front.
    func focusWindow(isEditModeEnabled: Bool) {
        guard !isEditModeEnabled,
              let windowID = selectedWindow?.owningApplication?.processID else {
            logger.warning("Cannot focus window: Edit mode is on or no window selected.")
            return
        }
        NSRunningApplication(processIdentifier: pid_t(windowID))?
            .activate(options: [.activateAllWindows])
    }

    // MARK: - Private Methods
    /// Filters out unwanted windows from the list of available windows.
    private func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        windows.filter { window in
            // Basic criteria
            let isValidWindow = window.isOnScreen &&
                                window.frame.height > 100 &&  // Lowered from 400 to catch smaller but valid windows
                                window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier

            // Additional criteria to exclude non-window elements
            let isNotMenuBarOrDock = window.windowLayer == 0  // Main windows are typically on layer 0
            let hasValidTitle = window.title != nil && !window.title!.isEmpty
            let isNotDesktop = window.owningApplication?.bundleIdentifier != "com.apple.finder" || window.title != "Desktop"
            let isNotSystemUIServer = window.owningApplication?.bundleIdentifier != "com.apple.systemuiserver"

            // Exclude known system tray and status bar apps
            let systemAppBundleIDs = ["com.apple.controlcenter", "com.apple.notificationcenterui"]
            let isNotSystemApp = !systemAppBundleIDs.contains(window.owningApplication?.bundleIdentifier ?? "")

            return isValidWindow && isNotMenuBarOrDock && hasValidTitle && isNotDesktop && isNotSystemUIServer && isNotSystemApp
        }
    }

    /// Creates a stream configuration for the given window.
    private func createStreamConfiguration(for window: SCWindow) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(appSettings.frameRate))
        config.queueDepth = 8
        return config
    }
}
