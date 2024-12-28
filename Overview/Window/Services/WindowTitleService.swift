/*
 Window/Services/WindowTitleService.swift
 Overview

 Created by William Pierce on 12/15/24.
*/

import ScreenCaptureKit

final class WindowTitleService {
    private let logger = AppLogger.windows

    func updateWindowTitle(for window: SCWindow?) async -> String? {
        guard let window = window else {
            logger.debug("Title update skipped: nil window reference")
            return nil
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: false)

            let title = content.windows.first { updatedWindow in
                updatedWindow.owningApplication?.processID == window.owningApplication?.processID
                    && updatedWindow.windowID == window.windowID
            }?.title

            if let title = title {
                logger.debug("Title updated: '\(title)'")
            } else {
                logger.warning("No matching window found for title update")
            }

            return title
        } catch {
            logger.error("Title update failed: \(error.localizedDescription)")
            return nil
        }
    }
}
