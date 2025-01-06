/*
 Source/SourceServices.swift
 Overview

 Created by William Pierce on 12/15/24.

 Provides centralized access to source window-related services including filtering,
 focus management, and state observation.
*/

import ScreenCaptureKit

/// Coordinates source window-related services and provides centralized access to
/// window management functionality across the application.
@MainActor
final class SourceServices {
    let sourceFilter: SourceFilterService
    let sourceFocus: SourceFocusService
    let sourceObserver: SourceObserverService
    private let logger = AppLogger.sources
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
