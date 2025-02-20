/*
 Source/Services/SourceFocusService.swift
 Overview

 Created by William Pierce on 12/15/24.

 Manages source window focus operations and application activation.
*/

import ScreenCaptureKit

final class SourceFocusService {
    private let logger = AppLogger.sources
    private let sourceFocusCheckInterval: TimeInterval = 0.05  // 100ms interval for focus checks
    private var focusCheckTimer: Timer?
    private var onFocusChanged: ((Bool) -> Void)?

    deinit {
        stopFocusChecking()
    }

    // MARK: - Public Methods

    func startFocusChecking(
        forWindowID windowID: CGWindowID, processID: pid_t, onChange: @escaping (Bool) -> Void
    ) {
        stopFocusChecking()
        onFocusChanged = onChange

        focusCheckTimer = Timer.scheduledTimer(
            withTimeInterval: sourceFocusCheckInterval, repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            let isFocused = self.isWindowFocused(windowID: windowID, processID: processID)
            onChange(isFocused)
        }
    }

    func stopFocusChecking() {
        focusCheckTimer?.invalidate()
        focusCheckTimer = nil
        onFocusChanged = nil
    }

    func focusSource(source: SCWindow) {
        guard let processID: pid_t = source.owningApplication?.processID else {
            logger.warning("No process ID found for source: '\(source.title ?? "untitled")'")
            return
        }

        logger.debug("Focusing source: '\(source.title ?? "untitled")', processID=\(processID)")

        // Create AX UI elements for the application
        let axApp = AXUIElementCreateApplication(processID)

        // Get the windows list from the application
        var windowList: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowList)

        guard let windows = windowList as? [AXUIElement] else {
            logger.error("Failed to get window list for process: \(processID)")
            return
        }

        // Find the matching window by its ID
        for axWindow: AXUIElement in windows {
            if IDFinder.getWindowID(axWindow) == source.windowID {
                // Found matching window, set focus attributes
                setWindowFocus(axApp: axApp, axWindow: axWindow)
                logger.info("Source window successfully focused: '\(source.title ?? "untitled")'")
                return
            }
        }

        logger.error("Failed to find matching window for source: '\(source.title ?? "untitled")'")
    }

    func focusSource(withTitle title: String) -> Bool {
        logger.debug("Processing title-based focus request: '\(title)'")

        // Get list of all windows
        let options = CGWindowListOption(arrayLiteral: .optionAll)
        let cgWindowList =
            CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] ?? []

        logger.debug("Searching \(cgWindowList.count) windows for title match: '\(title)'")

        // Find window with matching title
        guard
            let windowInfo = cgWindowList.first(where: { info in
                guard let windowTitle = info[kCGWindowName] as? String else { return false }
                return windowTitle == title
            }),
            let windowID = windowInfo[kCGWindowNumber] as? CGWindowID,
            let pid = windowInfo[kCGWindowOwnerPID] as? pid_t
        else {
            logger.warning("No matching window found: '\(title)'")
            return false
        }

        // Create accessibility elements
        let axApp: AXUIElement = AXUIElementCreateApplication(pid)
        var axWindowList: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &axWindowList)

        guard let windows = axWindowList as? [AXUIElement] else {
            logger.error("Failed to get window list for process: \(pid)")
            return false
        }

        // Find the specific window by ID
        for axWindow in windows {
            if IDFinder.getWindowID(axWindow) == windowID {
                setWindowFocus(axApp: axApp, axWindow: axWindow)
                logger.info("Title-based window focus successful: '\(title)'")
                return true
            }
        }

        logger.error("Failed to focus window: '\(title)'")
        return false
    }

    // MARK: - Private Methods

    func isWindowFocused(windowID: CGWindowID, processID: pid_t) -> Bool {
        let axApp: AXUIElement = AXUIElementCreateApplication(processID)

        // Get focused window from application
        var focusedWindowRef: CFTypeRef?
        AXUIElementCopyAttributeValue(
            axApp, kAXFocusedWindowAttribute as CFString, &focusedWindowRef)

        guard let focusedWindow = focusedWindowRef as! AXUIElement? else {
            return false
        }

        let focusedWindowID: CGWindowID = IDFinder.getWindowID(focusedWindow)
        return focusedWindowID == windowID
    }

    private func setWindowFocus(axApp: AXUIElement, axWindow: AXUIElement) {
        // Set application as frontmost
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        // Set window as main and focused
        AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }
}

// MARK: - Window ID Helper

private enum IDFinder {
    static func getWindowID(_ window: AXUIElement) -> CGWindowID {
        var windowID: CGWindowID = 0

        // Private API to get window ID from AXUIElement
        typealias GetWindowFunc = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) ->
            AXError
        let handle: UnsafeMutableRawPointer? = dlopen(
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_NOW
        )
        let sym: UnsafeMutableRawPointer? = dlsym(handle, "_AXUIElementGetWindow")
        let fn: GetWindowFunc = unsafeBitCast(sym, to: GetWindowFunc.self)
        _ = fn(window, &windowID)
        dlclose(handle)

        return windowID
    }
}
