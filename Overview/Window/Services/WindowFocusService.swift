/*
 Window/Services/WindowFocusService.swift
 Overview

 Created by William Pierce on 12/15/24.

 Manages window focus operations and application activation.
*/

import ScreenCaptureKit

/// Handles window focusing operations including process activation
/// and window-specific focus management.
final class WindowFocusService {
    private let logger = AppLogger.windows

    // MARK: - Public Methods

    func focusWindow(window: SCWindow) {
        guard let processID: pid_t = window.owningApplication?.processID else {
            logger.warning("No process ID found for window: '\(window.title ?? "untitled")'")
            return
        }

        logger.debug("Focusing window: '\(window.title ?? "untitled")', processID=\(processID)")

        let success: Bool = activateProcess(processID)

        if success {
            logger.info("Window successfully focused: '\(window.title ?? "untitled")'")
        } else {
            logger.error("Window focus failed: processID=\(processID)")
        }
    }

    func focusWindow(withTitle title: String) -> Bool {
        logger.debug("Processing title-based focus request: '\(title)'")

        guard let runningApp: NSRunningApplication = findApplication(forWindowTitle: title) else {
            logger.warning("No application found for window: '\(title)'")
            return false
        }

        NSApp.activate(ignoringOtherApps: true)
        let success: Bool = runningApp.activate()

        if success {
            logger.info("Title-based focus successful: '\(title)'")
        } else {
            logger.error("Title-based focus failed: '\(title)'")
        }

        return success
    }

    // MARK: - Private Methods

    private func findApplication(forWindowTitle title: String) -> NSRunningApplication? {
        let options = CGWindowListOption(arrayLiteral: .optionAll)
        let windowList =
            CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] ?? []

        logger.debug("Searching \(windowList.count) windows for title match: '\(title)'")

        guard
            let windowInfo = windowList.first(where: { info in
                guard let windowTitle = info[kCGWindowName] as? String,
                    !windowTitle.isEmpty
                else { return false }
                return windowTitle == title
            }), let windowPID = windowInfo[kCGWindowOwnerPID] as? pid_t
        else {
            logger.warning("No matching window found: '\(title)'")
            return nil
        }

        let runningApp: NSRunningApplication? = NSWorkspace.shared.runningApplications.first {
            app in
            app.processIdentifier == windowPID
        }

        if let app: NSRunningApplication = runningApp {
            logger.debug("Found application: '\(app.localizedName ?? "unknown")', pid=\(windowPID)")
        }

        return runningApp
    }

    private func activateProcess(_ processID: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: processID) else {
            logger.error("Invalid process ID: \(processID)")
            return false
        }
        return app.activate()
    }
}
