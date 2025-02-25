/*
 Window/WindowServices.swift
 Overview

 Created by William Pierce on 1/14/25.

 Provides centralized access to window services.
*/

import ScreenCaptureKit

@MainActor
final class WindowServices {
    // Dependencies
    let windowAspect: WindowAspectService
    let windowConfiguration: WindowConfigurationService
    let windowPosition: WindowPositionService
    let windowStorage: WindowStorage
    private let logger = AppLogger.interface

    // Singleton
    static let shared = WindowServices()

    private init() {
        self.windowAspect = WindowAspectService()
        self.windowConfiguration = WindowConfigurationService()
        self.windowPosition = WindowPositionService()
        self.windowStorage = WindowStorage.shared
        logger.debug("Initializing window services")
    }

    func createWindow(defaultSize: CGSize, windowCount: Int, providedFrame: NSRect? = nil) throws
        -> NSWindow
    {
        let windowFrame: NSRect
        if let frame: NSRect = providedFrame {
            windowFrame = frame.ensureOnScreen()
        } else {
            windowFrame = try windowPosition.createDefaultFrame(
                defaultWidth: defaultSize.width,
                defaultHeight: defaultSize.height,
                windowCount: windowCount
            )
        }

        let window = try windowConfiguration.createWindow(with: windowFrame)
        return window
    }
}
