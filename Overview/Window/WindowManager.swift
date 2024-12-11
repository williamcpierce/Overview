/*
 WindowManager.swift
 Overview

 Created by William Pierce on 12/10/24
 
 Provides centralized window management capabilities, handling window operations
 across the application in a simpler, more maintainable way.

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
    }
    
    private let logger = Logger(subsystem: "com.Overview.WindowManager", category: "WindowManagement")
    private let shareableContent = ShareableContentService()
    private var windowCache: [String: WindowState] = [:]
    private var updateTimer: Timer?
    
    private let systemAppBundleIDs = [
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
    ]
    
    private init() {
        startWindowTracking()
    }
    
    func getAvailableWindows() async -> [SCWindow] {
        await updateWindowState()
        return Array(windowCache.values.map { $0.window })
    }
    
    func findWindow(withTitle title: String) -> SCWindow? {
        windowCache[title]?.window
    }
    
    @discardableResult
    func focusWindow(withTitle title: String) -> Bool {
        guard let windowState = windowCache[title],
              let processID = windowState.window.owningApplication?.processID else {
            return false
        }
        
        return NSRunningApplication(processIdentifier: pid_t(processID))?.activate() ?? false
    }
    
    func isWindowFocused(_ window: SCWindow) -> Bool {
        guard let title = window.title else { return false }
        return windowCache[title]?.isFocused ?? false
    }
    
    func updateWindowState() async {
        do {
            let windows = try await shareableContent.getAvailableWindows()
            let filtered = filterWindows(windows)
            let activeApp = NSWorkspace.shared.frontmostApplication
            
            windowCache.removeAll()
            
            for window in filtered {
                guard let title = window.title else { continue }
                let isFocused = window.owningApplication?.processID == activeApp?.processIdentifier
                windowCache[title] = WindowState(window: window, isFocused: isFocused, title: title)
            }
        } catch {
            logger.error("Failed to update window state: \(error.localizedDescription)")
        }
    }
    
    private func startWindowTracking() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
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
        window.isOnScreen &&
        window.frame.height > 100 &&
        window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier &&
        window.windowLayer == 0 &&
        window.title != nil &&
        !window.title!.isEmpty
    }
    
    private func isSystemWindow(_ window: SCWindow) -> Bool {
        let isDesktop = window.owningApplication?.bundleIdentifier == "com.apple.finder" && window.title == "Desktop"
        let isSystemUI = window.owningApplication?.bundleIdentifier == "com.apple.systemuiserver"
        let isSystemApp = systemAppBundleIDs.contains(window.owningApplication?.bundleIdentifier ?? "")
        
        return isDesktop || isSystemUI || isSystemApp
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}
