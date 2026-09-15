/*
 Source/Services/SourceFilterService.swift
 Overview

 Filters shareable windows for preview pickers. This fork only lists
 EVE Online clients (CCP bundle IDs / known EVE app names).
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

    func filterSources(_ sources: [SCWindow]) -> [SCWindow] {
        logger.debug("Starting source filtering: total=\(sources.count)")

        let filtered: [SCWindow] = sources.filter { source in
            meetsBasicRequirements(source)
                && isNotSystemComponent(source)
                && isEveOnlineClient(source)
        }

        logger.debug(
            "Source filtering complete: valid=\(filtered.count), filtered=\(sources.count - filtered.count)"
        )
        return filtered
    }

    // MARK: - Private Methods

    private func isEveOnlineClient(_ source: SCWindow) -> Bool {
        EveSourceMatcher.isAllowed(
            bundleID: source.owningApplication?.bundleIdentifier,
            applicationName: source.owningApplication?.applicationName
        )
    }

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
}
