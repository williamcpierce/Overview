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

    // MARK: - Public Methods

    func focusSource(source: SCWindow) {
        guard let processID: pid_t = source.owningApplication?.processID else {
            logger.warning("No process ID found for source: '\(source.title ?? "untitled")'")
            return
        }

        logger.debug("Focusing source: '\(source.title ?? "untitled")', processID=\(processID)")

        let axApp: AXUIElement = AXUIElementCreateApplication(processID)
        let windows: [AXUIElement] = getWindowList(for: axApp)

        guard
            let matchingWindow: AXUIElement = findMatchingWindow(windows, targetID: source.windowID)
        else {
            logger.error(
                "Failed to find matching window for source: '\(source.title ?? "untitled")'")
            return
        }

        setWindowFocus(axApp: axApp, axWindow: matchingWindow)
        logger.info("Source window successfully focused: '\(source.title ?? "untitled")'")
    }

    func focusSource(withTitle title: String) -> Bool {
        logger.debug("Processing title-based focus request: '\(title)'")

        let options = CGWindowListOption(arrayLiteral: .optionAll)
        let windowList =
            CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] ?? []

        guard let (windowID, pid) = findWindowInfo(for: title, in: windowList) else {
            logger.warning("No matching window found: '\(title)'")
            return false
        }

        let axApp: AXUIElement = AXUIElementCreateApplication(pid)
        let windows: [AXUIElement] = getWindowList(for: axApp)

        guard let matchingWindow: AXUIElement = findMatchingWindow(windows, targetID: windowID)
        else {
            logger.error("Failed to focus window: '\(title)'")
            return false
        }

        setWindowFocus(axApp: axApp, axWindow: matchingWindow)
        logger.info("Title-based window focus successful: '\(title)'")
        return true
    }

    // MARK: - Private Methods

    private func isWindowFocused(windowID: CGWindowID, processID: pid_t) -> Bool {
        let axApp: AXUIElement = AXUIElementCreateApplication(processID)
        var focusedWindowRef: CFTypeRef?

        AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowRef
        )

        guard let focusedWindow = focusedWindowRef as! AXUIElement? else {
            return false
        }

        let focusedWindowID: CGWindowID = WindowIDUtility.extractWindowID(from: focusedWindow)
        return focusedWindowID == windowID
    }

    private func getWindowList(for axApp: AXUIElement) -> [AXUIElement] {
        var windowList: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowList)
        return windowList as? [AXUIElement] ?? []
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

    private func setWindowFocus(axApp: AXUIElement, axWindow: AXUIElement) {
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
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
