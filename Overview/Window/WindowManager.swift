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
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                let filtered = filterWindows(content.windows)
                let activeApp = NSWorkspace.shared.frontmostApplication
                
                var newCache: [String: WindowState] = [:]
                
                for window in filtered {
                    guard let processID = window.owningApplication?.processID,
                          let title = window.title else { continue }
                    
                    let existingState = windowCache.values.first { state in
                        state.processID == processID && state.frame == window.frame
                    }
                    
                    let isFocused = existingState?.isFocused ?? (processID == activeApp?.processIdentifier)
                    newCache[title] = WindowState(window: window, isFocused: isFocused, title: title)
                }
                
                if let activeProcessID = activeApp?.processIdentifier {
                    for (title, state) in newCache where state.processID == activeProcessID {
                        newCache[title] = WindowState(window: state.window, isFocused: true, title: title)
                    }
                }
                
                windowCache = newCache
                
            } catch {
                logger.error("Failed to update window state: \(error.localizedDescription)")
            }
        }
    
    private func startWindowTracking() {
        // More frequent updates for responsive UI
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateWindowState()
            }
        }
    }
    
    func subscribeToWindowState(_ window: SCWindow, onUpdate: @escaping (Bool, String?) -> Void) {
        guard let processID = window.owningApplication?.processID else { return }
        let frame = window.frame
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Find window by processID and frame
                if let state = self.windowCache.values.first(where: { state in
                    state.processID == processID && state.frame == frame
                }) {
                    onUpdate(state.isFocused, state.title)
                }
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
