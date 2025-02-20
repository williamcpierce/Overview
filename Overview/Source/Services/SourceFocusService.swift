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

        NSApp.activate(ignoringOtherApps: true)
        let success: Bool = runningApp.activate()

        if success {
            logger.info("Title-based focus successful: '\(title)'")
        } else {
            logger.error("Title-based focus failed: '\(title)'")
        }

        return success
    }

    func getActiveWindowTitle() -> String? {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
        let windowList =
            CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] ?? []

        guard let frontmostApp: NSRunningApplication = NSWorkspace.shared.frontmostApplication
        else {
            return nil
        }

        let frontPID: pid_t = frontmostApp.processIdentifier

        return windowList.first { info in
            guard let windowPID = info[kCGWindowOwnerPID] as? pid_t,
                windowPID == frontPID,
                let title = info[kCGWindowName] as? String,
                !title.isEmpty
            else { return false }
            return true
        }?[kCGWindowName] as? String
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

        let runningApp: NSRunningApplication? = NSWorkspace.shared.runningApplications.first {
            app in
            app.processIdentifier == sourcePID
        }

        if let app: NSRunningApplication = runningApp {
            logger.debug("Found application: '\(app.localizedName ?? "unknown")', pid=\(sourcePID)")
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
