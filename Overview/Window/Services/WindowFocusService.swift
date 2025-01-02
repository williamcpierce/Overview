/*
 Window/Services/WindowFocusService.swift
 Overview

 Created by William Pierce on 12/15/24.
*/

import ScreenCaptureKit

final class WindowFocusService {
    private let logger = AppLogger.windows

    func focusWindow(window: SCWindow) {
        guard let processID = window.owningApplication?.processID else {
            logger.warning("No process ID found for window: '\(window.title ?? "untitled")'")
            return
        }

        logger.debug(
            "Focusing window: '\(window.title ?? "untitled")', processID=\(String(describing: processID))"
        )

        let success = activateProcess(processID)

        if success {
            logger.info("Window successfully focused: '\(window.title ?? "untitled")'")
        } else {
            logger.error("Window focus failed: processID=\(String(describing: processID))")
        }
    }

    func focusWindow(withTitle title: String) -> Bool {
        logger.debug("Processing title-based focus request: '\(title)'")

        guard let runningApp = findApplication(forWindowTitle: title) else {
            logger.warning("No application found for window: '\(title)'")
            return false
        }

        NSApp.activate(ignoringOtherApps: true)
        let success = runningApp.activate()

        if success {
            logger.info("Title-based focus successful: '\(title)'")
        } else {
            logger.error("Title-based focus failed: '\(title)'")
        }

        return success
    }

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

        let runningApp = NSWorkspace.shared.runningApplications.first { app in
            app.processIdentifier == windowPID
        }

        if let app = runningApp {
            logger.debug("Found application: '\(app.localizedName ?? "unknown")', pid=\(windowPID)")
        } else {
            logger.warning("No running application for pid=\(windowPID)")
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

    func updateFocusState(for window: SCWindow?) async -> Bool {
        guard let window = window,
            let activeApp = NSWorkspace.shared.frontmostApplication,
            let selectedApp = window.owningApplication
        else {
            logger.debug("Focus state check failed: missing window or app reference")
            return false
        }

        let isFocused = activeApp.processIdentifier == selectedApp.processID

        if isFocused {
            logger.debug("Window is focused: '\(window.title ?? "untitled")'")
        }

        return isFocused
    }
}
