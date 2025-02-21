/*
 Source/Services/SourceFocusService.swift
 Overview

 Created by William Pierce on 12/15/24.

 Manages source window focus operations and application activation.
*/

import ApplicationServices
import ScreenCaptureKit

final class SourceFocusService {
    // Dependencies
    private let logger = AppLogger.sources
    private let workspace = NSWorkspace.shared

    // Private State
    private var windowFocusCache: [String: (pid_t, CGWindowID)] = [:]
    private var lastCacheUpdate = Date()
    private let cacheDuration: TimeInterval = 5.0

    // MARK: - Public Methods

    func focusSource(source: SCWindow, completion: (() -> Void)? = nil) {
        guard let processID = source.owningApplication?.processID else {
            logger.warning("No process ID found for source: '\(source.title ?? "untitled")'")
            return
        }

        logger.debug("Focusing source: '\(source.title ?? "untitled")', processID=\(processID)")

        Task { @MainActor in
            if await setWindowFocus(processID: processID, windowID: source.windowID) {
                logger.info("Source window successfully focused: '\(source.title ?? "untitled")'")
                if let title = source.title {
                    updateWindowCache(title: title, processID: processID, windowID: source.windowID)
                }
                completion?()
            } else {
                logger.error("Failed to focus source window: '\(source.title ?? "untitled")'")
            }
        }
    }

    func focusSource(withTitle title: String, completion: (() -> Void)? = nil) -> Bool {
        logger.debug("Processing title-based focus request: '\(title)'")

        // Check cached window info first
        if let (pid, windowID) = getCachedWindowInfo(for: title) {
            Task { @MainActor in
                if await setWindowFocus(processID: pid, windowID: windowID) {
                    logger.info("Window focused using cached info: '\(title)'")
                    completion?()
                }
            }
            return true
        }

        // Fallback to searching window list
        let success = searchAndFocusWindow(byTitle: title)
        if success {
            completion?()
        }
        return success
    }

    // MARK: - Private Methods

    private func getCachedWindowInfo(for title: String) -> (pid_t, CGWindowID)? {
        guard Date().timeIntervalSince(lastCacheUpdate) < cacheDuration else {
            windowFocusCache.removeAll()
            return nil
        }
        return windowFocusCache[title]
    }

    private func updateWindowCache(title: String, processID: pid_t, windowID: CGWindowID) {
        windowFocusCache[title] = (processID, windowID)
        lastCacheUpdate = Date()
    }

    private func searchAndFocusWindow(byTitle title: String) -> Bool {
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard
            let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
                as? [[CFString: Any]]
        else {
            logger.warning("Unable to retrieve window list")
            return false
        }

        guard let (windowID, pid) = findWindowInfo(for: title, in: windowList) else {
            logger.warning("No matching window found: '\(title)'")
            return false
        }

        updateWindowCache(title: title, processID: pid, windowID: windowID)

        Task { @MainActor in
            _ = await setWindowFocus(processID: pid, windowID: windowID)
        }
        return true
    }

    private func findWindowInfo(for title: String, in windowList: [[CFString: Any]]) -> (
        CGWindowID, pid_t
    )? {
        guard
            let windowInfo = windowList.first(where: { ($0[kCGWindowName] as? String) == title }),
            let windowID = windowInfo[kCGWindowNumber] as? CGWindowID,
            let pid = windowInfo[kCGWindowOwnerPID] as? pid_t
        else { return nil }

        return (windowID, pid)
    }

    private func setWindowFocus(processID: pid_t, windowID: CGWindowID) async -> Bool {
        // First activate the application
        guard let runningApp = NSRunningApplication(processIdentifier: processID) else {
            logger.error("Could not find running application for pid: \(processID)")
            return false
        }

        // Activate the application first
        guard await activateApplication(runningApp) else {
            logger.error("Failed to activate application: \(runningApp.localizedName ?? "unknown")")
            return false
        }

        // Get the AX element for the application
        let axApp = AXUIElementCreateApplication(processID)
        let windows = getWindowList(for: axApp)

        guard
            let matchingWindow = windows.first(where: {
                WindowIDUtility.extractWindowID(from: $0) == windowID
            })
        else {
            logger.error("Could not find matching window in AX hierarchy")
            return false
        }

        // Check if window is full screen
        var value: AnyObject?
        let fullScreenAttr = "AXFullScreen" as CFString
        AXUIElementCopyAttributeValue(matchingWindow, fullScreenAttr, &value)
        let isFullScreen = (value as? Bool) ?? false

        if isFullScreen {
            logger.debug("Handling full screen window focus")
            return await handleFullScreenWindowFocus(matchingWindow, axApp)
        } else {
            return await handleRegularWindowFocus(matchingWindow, axApp)
        }
    }

    private func activateApplication(_ app: NSRunningApplication) async -> Bool {
        // If app is already active, return true
        if app.isActive {
            return true
        }

        // Attempt to activate the application
        let activated: Bool = app.activate(options: [.activateIgnoringOtherApps])

        if activated {
            // Wait briefly for activation to complete
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
            return true
        }

        return false
    }

    private func handleFullScreenWindowFocus(_ window: AXUIElement, _ app: AXUIElement) async
        -> Bool
    {
        // For full screen windows, we need to:
        // 1. Ensure the window is still full screen
        // 2. Set it as the main and focused window
        let attributes: [(AXUIElement, CFString, CFTypeRef)] = [
            (app, kAXFrontmostAttribute as CFString, kCFBooleanTrue),
            (window, kAXMainAttribute as CFString, kCFBooleanTrue),
            (window, kAXFocusedAttribute as CFString, kCFBooleanTrue),
        ]

        // Apply all attributes and ensure they succeed
        let success: Bool = attributes.allSatisfy { element, attribute, value in
            AXUIElementSetAttributeValue(element, attribute, value) == .success
        }

        if success {
            // Wait briefly to ensure focus changes are applied
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        }

        return success
    }

    private func handleRegularWindowFocus(_ window: AXUIElement, _ app: AXUIElement) async -> Bool {
        // For regular windows, we:
        // 1. Raise the window to front
        // 2. Set it as main and focused
        var position = CGPoint.zero
        var size = CGSize.zero

        // Get current position and size
        var positionValue: AnyObject?
        var sizeValue: AnyObject?

        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        if let positionAXValue = positionValue as! AXValue? {
            AXValueGetValue(positionAXValue, .cgPoint, &position)
        }

        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)
        if let sizeAXValue = sizeValue as! AXValue? {
            AXValueGetValue(sizeAXValue, .cgSize, &size)
        }

        // Create new position value slightly offset (forces window to front)
        guard let newPosition = AXValueCreate(.cgPoint, &position) else {
            return false
        }

        let attributes: [(AXUIElement, CFString, CFTypeRef)] = [
            (app, kAXFrontmostAttribute as CFString, kCFBooleanTrue),
            (window, kAXPositionAttribute as CFString, newPosition),
            (window, kAXMainAttribute as CFString, kCFBooleanTrue),
            (window, kAXFocusedAttribute as CFString, kCFBooleanTrue),
        ]

        let success: Bool = attributes.allSatisfy { element, attribute, value in
            AXUIElementSetAttributeValue(element, attribute, value) == .success
        }

        if success {
            // Wait briefly to ensure focus changes are applied
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        }

        return success
    }

    private func getWindowList(for axApp: AXUIElement) -> [AXUIElement] {
        var windowList: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowList)
        return windowList as? [AXUIElement] ?? []
    }
}
