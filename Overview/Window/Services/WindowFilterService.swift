/*
 Window/Services/WindowFilterService.swift
 Overview

 Created by William Pierce on 12/15/24.

 Handles window filtering operations based on system requirements and user preferences.
*/

import ScreenCaptureKit

/// Provides window filtering capabilities based on system requirements,
/// user-defined filters, and application-specific rules.
final class WindowFilterService {
    private let logger = AppLogger.windows
    private let systemAppBundleIDs: Set<String> = Set([
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.WindowManager",
    ])

    // MARK: - Public Methods

    func filterWindows(
        _ windows: [SCWindow],
        appFilterNames: [String],
        isFilterBlocklist: Bool
    ) -> [SCWindow] {
        logger.debug("Starting window filtering: total=\(windows.count)")

        let filtered: [SCWindow] = windows.filter { window in
            meetsBasicRequirements(window)
                && isNotSystemComponent(window)
                && passesFilter(
                    window, appFilterNames: appFilterNames, isFilterBlocklist: isFilterBlocklist)
        }

        logger.debug(
            "Window filtering complete: valid=\(filtered.count), filtered=\(windows.count - filtered.count)"
        )
        return filtered
    }

    // MARK: - Private Methods

    private func meetsBasicRequirements(_ window: SCWindow) -> Bool {
        let isValid: Bool =
            window.frame.height > 100
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
        let isNotDesktopView: Bool =
            window.owningApplication?.bundleIdentifier != "com.apple.finder"
            || window.title != "Desktop"

        let isNotSystemUI: Bool =
            window.owningApplication?.bundleIdentifier != "com.apple.systemuiserver"

        let isNotSystemApp: Bool = !systemAppBundleIDs.contains(
            window.owningApplication?.bundleIdentifier ?? "")

        let isNotSystem: Bool = isNotDesktopView && isNotSystemUI && isNotSystemApp

        if !isNotSystem {
            logger.debug(
                "Excluding system window: '\(window.title ?? "untitled")', bundleID=\(window.owningApplication?.bundleIdentifier ?? "unknown")"
            )
        }

        return isNotSystem
    }

    private func passesFilter(
        _ window: SCWindow,
        appFilterNames: [String],
        isFilterBlocklist: Bool
    ) -> Bool {
        let isMatchedByFilter: Bool = appFilterNames.contains(
            window.owningApplication?.applicationName ?? "")

        let passesFilter: Bool = isFilterBlocklist ? !isMatchedByFilter : isMatchedByFilter

        return passesFilter
    }
}
