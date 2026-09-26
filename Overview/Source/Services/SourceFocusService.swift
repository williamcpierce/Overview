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

        let success: Bool = activateProcess(processID)

        if success {
            logger.info("Source successfully focused: '\(source.title ?? "untitled")'")
        } else {
            logger.error("Source focus failed: processID=\(processID)")
        }
    }

    func focusSource(withTitle title: String) -> Bool {
        logger.debug("Processing title-based focus request: '\(title)'")

        guard let runningApp: NSRunningApplication = findApplication(forSourceTitle: title) else {
            logger.warning("No application found for source window: '\(title)'")
            return false
        }

        let success: Bool = activate(runningApp)

        if success {
            logger.info("Title-based focus successful: '\(title)'")
        } else {
            logger.error("Title-based focus failed: '\(title)'")
        }

        return success
    }

    // MARK: - Private Methods

    private func findApplication(forSourceTitle title: String) -> NSRunningApplication? {
        let options = CGWindowListOption(arrayLiteral: .optionAll)
        let sourceList =
            CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] ?? []

        logger.debug("Searching \(sourceList.count) source windows for title match: '\(title)'")

        guard
            let sourceInfo = sourceList.first(where: { info in
                guard let sourceTitle = info[kCGWindowName] as? String,
                    !sourceTitle.isEmpty
                else { return false }
                return sourceTitle == title
            }), let sourcePID = sourceInfo[kCGWindowOwnerPID] as? pid_t
        else {
            logger.warning("No matching source window found: '\(title)'")
            return nil
        }

        // Resolve by PID directly: `NSWorkspace.runningApplications` can omit
        // processes that the window server (and ScreenCaptureKit) still report.
        guard let runningApp = NSRunningApplication(processIdentifier: sourcePID) else {
            logger.warning("No running application for pid=\(sourcePID), title: '\(title)'")
            return nil
        }

        logger.debug(
            "Found application: '\(runningApp.localizedName ?? "unknown")', pid=\(sourcePID)")
        return runningApp
    }

    private func activateProcess(_ processID: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: processID) else {
            logger.error("Invalid process ID: \(processID)")
            return false
        }
        return activate(app)
    }

    /// Brings another application to the front.
    ///
    /// Since macOS 14 activation is cooperative: the active app must hand
    /// activation to the target via `activate(from:options:)`. The legacy
    /// `activate()` still worked on macOS 26 but is refused on macOS 27.
    private func activate(_ app: NSRunningApplication) -> Bool {
        if #available(macOS 14.0, *) {
            NSApp.activate()

            if app.activate(from: .current, options: []) {
                return true
            }

            logger.debug(
                "Cooperative activation refused (overviewActive=\(NSApp.isActive)), yielding")
            NSApp.yieldActivation(to: app)
            return app.activate()
        }

        NSApp.activate(ignoringOtherApps: true)
        return app.activate()
    }
}
