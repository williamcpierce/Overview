/*
 Source/Services/SourceFocusService.swift
 Overview

 Created by William Pierce on 12/15/24.

 Manages source window focus operations and application activation.
*/

import ScreenCaptureKit

final class SourceFocusService {
    private let logger = AppLogger.sources

    // MARK: - Public Methods

    func focusSource(source: SCWindow) {
        guard let processID: pid_t = source.owningApplication?.processID else {
            logger.warning("No process ID found for source: '\(source.title ?? "untitled")'")
            return
        }

        logger.debug("Focusing source: '\(source.title ?? "untitled")', processID=\(processID)")

        // Create AX UI elements for the application and window
        let axApp = AXUIElementCreateApplication(processID)

        // Get the windows list from the application
        var windowList: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowList)

        guard let windows = windowList as? [AXUIElement] else {
            logger.error("Failed to get window list for process: \(processID)")
            return
        }

        // Find the matching window by its title
        for axWindow in windows {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)

            if let windowTitle = titleValue as? String,
                windowTitle == source.title
            {
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
            let pid = windowInfo[kCGWindowOwnerPID] as? pid_t
        else {
            logger.warning("No matching window found: '\(title)'")
            return false
        }

        // Create accessibility elements
        let axApp = AXUIElementCreateApplication(pid)
        var axWindowList: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &axWindowList)

        guard let windows = axWindowList as? [AXUIElement] else {
            logger.error("Failed to get window list for process: \(pid)")
            return false
        }

        // Find the specific window
        for axWindow in windows {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)

            if let windowTitle = titleValue as? String,
                windowTitle == title
            {
                setWindowFocus(axApp: axApp, axWindow: axWindow)
                logger.info("Title-based window focus successful: '\(title)'")
                return true
            }
        }

        logger.error("Failed to focus window: '\(title)'")
        return false
    }

    // MARK: - Private Methods

    private func setWindowFocus(axApp: AXUIElement, axWindow: AXUIElement) {
        // Set application as frontmost
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        // Set window as main and focused
        AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }
}
