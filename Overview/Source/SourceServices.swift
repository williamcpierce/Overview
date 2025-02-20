/*
 Source/SourceServices.swift
 Overview

 Created by William Pierce on 12/15/24.

 Provides centralized access to source window-related services including filtering,
 focus management, and state observation.
*/

import ScreenCaptureKit

@MainActor
final class SourceServices {
    // Dependencies
    let sourceFilter: SourceFilterService
    let sourceFocus: SourceFocusService
    let sourceObserver: SourceObserverService
    private let logger = AppLogger.sources

    // Singleton
    static let shared = SourceServices()

    private init() {
        self.sourceFilter = SourceFilterService()
        self.sourceFocus = SourceFocusService()
        self.sourceObserver = SourceObserverService()
        logger.debug("Initializing source services")
    }

    // MARK: - Window Filtering

    func filterSources(_ sources: [SCWindow], appFilterNames: [String], isFilterBlocklist: Bool)
        -> [SCWindow]
    {
        sourceFilter.filterSources(
            sources, appFilterNames: appFilterNames, isFilterBlocklist: isFilterBlocklist)
    }

    // MARK: - Focus Management

    func focusSource(_ source: SCWindow) {
        sourceFocus.focusSource(source: source)
    }

    func focusSource(withTitle title: String) -> Bool {
        sourceFocus.focusSource(withTitle: title)
    }

    // MARK: - State Observation

    func addObserver(
        id: UUID,
        onFocusChanged: @escaping () async -> Void,
        onTitleChanged: @escaping () async -> Void
    ) {
        sourceObserver.addObserver(
            id: id,
            onFocusChanged: onFocusChanged,
            onTitleChanged: onTitleChanged
        )
    }

    func removeObserver(id: UUID) {
        sourceObserver.removeObserver(id: id)
    }
}
