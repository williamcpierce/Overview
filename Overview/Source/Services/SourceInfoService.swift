/*
 Source/Services/SourceInfoService.swift
 Overview

 Created by William Pierce on 02/20/25.

 Provides utility functions for retrieving information about source windows,
 including extracting window IDs and fetching focused window details.
*/

import Cocoa
import ScreenCaptureKit

final class SourceInfoService {
    private let logger = AppLogger.sources

    // MARK: - Public Methods

    /// Retrieves the window ID and title for a given process ID.
    func getWindowInfo(for pid: pid_t) -> (CGWindowID, String)? {
        let appElement = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?

        guard
            AXUIElementCopyAttributeValue(
                appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success
        else {
            logger.warning("Failed to retrieve focused window for PID: \(pid)")
            return nil
        }

        let windowElement = unsafeBitCast(windowRef, to: AXUIElement.self)
        var titleRef: CFTypeRef?

        guard
            AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef)
                == .success,
            let title = titleRef as? String
        else {
            logger.warning("Failed to retrieve title for window of PID: \(pid)")
            return nil
        }

        return (WindowIDUtility.extractWindowID(from: windowElement), title)
    }
}
