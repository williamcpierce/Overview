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
    @Published var isCapturing = false
    @Published var isSourceWindowFocused = false
    @Published var windowTitle: String?
    @Published var selectedWindow: SCWindow? {
        didSet {
            windowTitle = selectedWindow?.title
            Task { await updateFocusState() }
        }
    }

    // MARK: - Private Properties
    private var stream: SCStream?
    private let captureEngine = CaptureEngine()
    private var captureTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.Overview.ScreenCaptureManager", category: "ScreenCapture")
    private var appSettings: AppSettings
    private var workspaceObserver: NSObjectProtocol?
    private var windowObserver: NSObjectProtocol?
    private var titleCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()


    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        super.init()
        setupObservers()
    }
    
    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        titleCheckTimer?.invalidate()
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
    
    private func setupObservers() {
        // Workspace observer for application-level changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.updateFocusState()
            }
        }
        
        // Window observer for window-level changes
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.updateFocusState()
            }
        }
        
        // Add FPS observer
        appSettings.$frameRate
            .dropFirst() // Ignore initial value
            .sink { [weak self] _ in
                Task {
                    await self?.updateStreamConfiguration()
                }
            }
            .store(in: &cancellables)
        
        // Start timer for title checks only
        startTitleChecks()
    }
    
    private func startTitleChecks() {
        titleCheckTimer?.invalidate()
        titleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.updateWindowTitle()
            }
        }
    }
    
    private func updateFocusState() async {
        guard let selectedWindow = self.selectedWindow else {
            isSourceWindowFocused = false
            return
        }

        // Check focus state only
        if let activeApp = NSWorkspace.shared.frontmostApplication,
           let selectedApp = selectedWindow.owningApplication {
            isSourceWindowFocused = activeApp.processIdentifier == selectedApp.processID
        } else {
            isSourceWindowFocused = false
        }
    }
    
    private func updateWindowTitle() async {
        guard let selectedWindow = self.selectedWindow else {
            windowTitle = nil
            return
        }
            
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Find our selected window and update its title
            if let updatedWindow = content.windows.first(where: { window in
                window.owningApplication?.processID == selectedWindow.owningApplication?.processID &&
                window.frame == selectedWindow.frame
            }) {
                windowTitle = updatedWindow.title
            }
        } catch {
            logger.error("Failed to update window title: \(error.localizedDescription)")
        }
    }

    /// Creates a stream configuration for the given window.
    private func createStreamConfiguration(for window: SCWindow) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(self.appSettings.frameRate))
        config.queueDepth = 3
        config.showsCursor = false
        return config
    }
    
    private func updateStreamConfiguration() async {
        guard isCapturing, let window = selectedWindow else { return }
        
        let config = createStreamConfiguration(for: window)
        let filter = SCContentFilter(desktopIndependentWindow: window)
        
        do {
            try await captureEngine.stream?.updateConfiguration(config)
            logger.info("Successfully updated stream configuration with new FPS: \(self.appSettings.frameRate)")
        } catch {
            logger.error("Failed to update stream configuration: \(error.localizedDescription)")
        }
    }
}
