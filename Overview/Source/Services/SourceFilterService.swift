/*
 Source/Services/SourceFilterService.swift
 Overview

 Created by William Pierce on 12/15/24.

 Handles source window filtering operations based on basic requirements and user preferences.
*/

import ScreenCaptureKit

final class SourceFilterService {
    // Dependencies
    private let logger = AppLogger.sources

    // Constants
    private let systemAppBundleIDs: Set<String> = Set([
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.WindowManager",
    ])

    // MARK: - Public Methods

    func filterSources(
        _ sources: [SCWindow],
        appFilterNames: [String],
        isFilterBlocklist: Bool
    ) -> [SCWindow] {
        logger.debug("Starting source filtering: total=\(sources.count)")

        let filtered: [SCWindow] = sources.filter { source in
            meetsBasicRequirements(source)
                && isNotSystemComponent(source)
                && passesFilter(
                    source, appFilterNames: appFilterNames, isFilterBlocklist: isFilterBlocklist)
        }

        logger.debug(
            "Source filtering complete: valid=\(filtered.count), filtered=\(sources.count - filtered.count)"
        )
        return filtered
    }

    // MARK: - Private Methods

    private func meetsBasicRequirements(_ source: SCWindow) -> Bool {
        let isValid: Bool =
            source.frame.height > 100
            && source.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            && source.windowLayer == 0
            && source.title != nil
            && !source.title!.isEmpty

        return isValid
    }

    private func isNotSystemComponent(_ source: SCWindow) -> Bool {
        let isNotDesktopView: Bool =
            source.owningApplication?.bundleIdentifier != "com.apple.finder"
            || source.title != "Desktop"

        let isNotSystemUI: Bool =
            source.owningApplication?.bundleIdentifier != "com.apple.systemuiserver"

        let isNotSystemApp: Bool = !systemAppBundleIDs.contains(
            source.owningApplication?.bundleIdentifier ?? "")

        let isNotSystem: Bool = isNotDesktopView && isNotSystemUI && isNotSystemApp

        return isNotSystem
    }

    private func passesFilter(
        _ source: SCWindow,
        appFilterNames: [String],
        isFilterBlocklist: Bool
    ) -> Bool {
        let isMatchedByFilter: Bool = appFilterNames.contains(
            source.owningApplication?.applicationName ?? "")

        let passesFilter: Bool = isFilterBlocklist ? !isMatchedByFilter : isMatchedByFilter

        return passesFilter
    }
}
