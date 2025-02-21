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

        if setWindowFocus(processID: processID, windowID: source.windowID) {
            logger.info("Source window successfully focused: '\(source.title ?? "untitled")'")
            if let title = source.title {
                updateWindowCache(title: title, processID: processID, windowID: source.windowID)
            }
            // Immediately trigger the completion callback.
            completion?()
        } else {
            logger.error("Failed to focus source window: '\(source.title ?? "untitled")'")
        }
    }

    func focusSource(withTitle title: String, completion: (() -> Void)? = nil) -> Bool {
        logger.debug("Processing title-based focus request: '\(title)'")

        // Check cached window info first
        if let (pid, windowID) = getCachedWindowInfo(for: title) {
            if setWindowFocus(processID: pid, windowID: windowID) {
                logger.info("Window focused using cached info: '\(title)'")
                completion?()
                return true
            }
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
        let options: CGWindowListOption = [.optionAll]
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
        return setWindowFocus(processID: pid, windowID: windowID)
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

    private func setWindowFocus(processID: pid_t, windowID: CGWindowID) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: processID) else {
            return false
        }
        // Activate the application (this may trigger a space switch)
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        let axApp = AXUIElementCreateApplication(processID)
        let windows = getWindowList(for: axApp)

        guard
            let matchingWindow = windows.first(where: {
                WindowIDUtility.extractWindowID(from: $0) == windowID
            })
        else {
            return false
        }

        let attributes: [(AXUIElement, CFString, CFTypeRef)] = [
            (axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue),
            (matchingWindow, kAXMainAttribute as CFString, kCFBooleanTrue),
            (matchingWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue),
        ]

        return attributes.allSatisfy { AXUIElementSetAttributeValue($0.0, $0.1, $0.2) == .success }
    }

    private func getWindowList(for axApp: AXUIElement) -> [AXUIElement] {
        var windowList: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowList)
        return windowList as? [AXUIElement] ?? []
    }
}
