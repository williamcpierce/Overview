/*
 Window/Service/WindowFilterService.swift
 Overview

 Created by William Pierce on 12/15/24.
*/

import ScreenCaptureKit

final class WindowFilterService {
    private let logger = AppLogger.windows
    private let systemAppBundleIDs = Set([
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
    ])

    func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        logger.debug("Starting window filtering: total=\(windows.count)")
        let filtered = windows.filter { window in
            meetsBasicRequirements(window) && isNotSystemComponent(window)
        }
        logger.debug(
            "Window filtering complete: valid=\(filtered.count), filtered=\(windows.count - filtered.count)"
        )
        return filtered
    }

    private func meetsBasicRequirements(_ window: SCWindow) -> Bool {
        let isValid =
            window.isOnScreen
            && window.frame.height > 100
            && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            && window.windowLayer == 0
            && window.title != nil
            && !window.title!.isEmpty

        if !isValid {
            logger.debug(
                "Window failed validation: '\(window.title ?? "untitled")', height=\(window.frame.height), layer=\(window.windowLayer)"
            )
        }
        return isValid
    }

    private func isNotSystemComponent(_ window: SCWindow) -> Bool {
        let isNotDesktopView =
            window.owningApplication?.bundleIdentifier != "com.apple.finder"
            || window.title != "Desktop"

        let isNotSystemUI =
            window.owningApplication?.bundleIdentifier != "com.apple.systemuiserver"

        let isNotSystemApp = !systemAppBundleIDs.contains(
            window.owningApplication?.bundleIdentifier ?? "")

        let isNotSystem = isNotDesktopView && isNotSystemUI && isNotSystemApp

        if !isNotSystem {
            logger.debug(
                "Excluding system window: '\(window.title ?? "untitled")', bundleID=\(window.owningApplication?.bundleIdentifier ?? "unknown")"
            )
        }

        return isNotSystem
    }
}
