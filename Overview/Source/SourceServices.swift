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

    private init(
        sourceFilter: SourceFilterService = SourceFilterService(),
        sourceFocus: SourceFocusService = SourceFocusService(),
        sourceObserver: SourceObserverService = SourceObserverService()
    ) {
        self.sourceFilter = sourceFilter
        self.sourceFocus = sourceFocus
        self.sourceObserver = sourceObserver
        logger.debug("Initializing source window services")
    }
}
