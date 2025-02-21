/*
 Source/Services/SourceFocusService.swift
 Overview

 Created by William Pierce on 12/15/24.

 Manages source window focus operations and application activation.
*/

import ScreenCaptureKit

final class SourceFocusService {
    // Dependencies
    private let logger = AppLogger.sources

    // Cache for window focus operations
    private var windowFocusCache: [String: (pid_t, CGWindowID)] = [:]
    private var lastCacheUpdate = Date()
    private let cacheDuration: TimeInterval = 5.0  // Cache valid for 5 seconds

    // MARK: - Public Methods

    func focusSource(source: SCWindow) {
        guard let processID: pid_t = source.owningApplication?.processID else {
            logger.warning("No process ID found for source: '\(source.title ?? "untitled")'")
            return
        }

        logger.debug("Focusing source: '\(source.title ?? "untitled")', processID=\(processID)")

        if setWindowFocus(processID: processID, windowID: source.windowID) {
            logger.info("Source window successfully focused: '\(source.title ?? "untitled")'")
            if let title: String = source.title {
                updateWindowCache(title: title, processID: processID, windowID: source.windowID)
            }
        } else {
            logger.error("Failed to focus source window: '\(source.title ?? "untitled")'")
        }
    }

    func focusSource(withTitle title: String) -> Bool {
        logger.debug("Processing title-based focus request: '\(title)'")

        // Check cache first if it's still valid
        if let (pid, windowID) = getCachedWindowInfo(for: title) {
            if setWindowFocus(processID: pid, windowID: windowID) {
                logger.info("Window focused using cached info: '\(title)'")
                return true
            }
        }

        // Fall back to full window list search
        let options = CGWindowListOption(arrayLiteral: .optionAll)
        let windowList =
            CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] ?? []

        guard let (windowID, pid) = findWindowInfo(for: title, in: windowList) else {
            logger.warning("No matching window found: '\(title)'")
            return false
        }

        // Update cache and attempt focus
        updateWindowCache(title: title, processID: pid, windowID: windowID)
        return setWindowFocus(processID: pid, windowID: windowID)
    }

    // MARK: - Private Methods

    private func getWindowList(for axApp: AXUIElement) -> [AXUIElement] {
        var windowList: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowList)
        return windowList as? [AXUIElement] ?? []
    }

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

    private func findMatchingWindow(_ windows: [AXUIElement], targetID: CGWindowID) -> AXUIElement?
    {
        windows.first { WindowIDUtility.extractWindowID(from: $0) == targetID }
    }

    private func findWindowInfo(for title: String, in windowList: [[CFString: Any]]) -> (
        CGWindowID, pid_t
    )? {
        guard
            let windowInfo = windowList.first(where: { info in
                guard let windowTitle = info[kCGWindowName] as? String else { return false }
                return windowTitle == title
            }),
            let windowID = windowInfo[kCGWindowNumber] as? CGWindowID,
            let pid = windowInfo[kCGWindowOwnerPID] as? pid_t
        else { return nil }

        return (windowID, pid)
    }

    private func setWindowFocus(processID: pid_t, windowID: CGWindowID) -> Bool {
        let axApp = AXUIElementCreateApplication(processID)
        let windows = getWindowList(for: axApp)

        guard let matchingWindow = findMatchingWindow(windows, targetID: windowID) else {
            return false
        }

        // Batch set focus attributes
        let attributeValues: [(AXUIElement, CFString, CFTypeRef)] = [
            (axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue),
            (matchingWindow, kAXMainAttribute as CFString, kCFBooleanTrue),
            (matchingWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue),
        ]

        let success = attributeValues.allSatisfy { element, attribute, value in
            AXUIElementSetAttributeValue(element, attribute, value) == .success
        }

        return success
    }
}

// MARK: - Window ID Utility

private enum WindowIDUtility {
    /// Extracts the window ID from an Accessibility UI Element
    static func extractWindowID(from window: AXUIElement) -> CGWindowID {
        var windowID: CGWindowID = 0

        // Retrieve window ID from AXUIElement using ApplicationServices framework
        typealias GetWindowFunc = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) ->
            AXError
        let frameworkHandle: UnsafeMutableRawPointer? = dlopen(
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices",
            RTLD_NOW
        )
        let windowSymbol: UnsafeMutableRawPointer? = dlsym(frameworkHandle, "_AXUIElementGetWindow")
        let retrieveWindowIDFunction: GetWindowFunc = unsafeBitCast(
            windowSymbol, to: GetWindowFunc.self)
        _ = retrieveWindowIDFunction(window, &windowID)
        dlclose(frameworkHandle)

        return windowID
    }
}
