/*
 Window/Services/WindowPositionService.swift
 Overview

 Created by William Pierce on 1/13/25.

 Manages window positioning and frame calculations, handling screen
 boundaries and cascading window placement.
*/

import AppKit

final class WindowPositionService {
    // Constants
    private struct Constants {
        static let cascadeOffset: CGFloat = 25
        static let fallbackPosition: CGFloat = 100
        static let minWidth: CGFloat = 160
        static let minHeight: CGFloat = 80
    }

    // Dependencies
    private let logger = AppLogger.interface

    func createDefaultFrame(
        defaultWidth: CGFloat,
        defaultHeight: CGFloat,
        windowCount: Int
    ) throws -> NSRect {
        guard let screen = NSScreen.main else {
            logger.warning("No main screen detected, using fallback dimensions")
            return createFallbackFrame(defaultWidth: defaultWidth, defaultHeight: defaultHeight)
        }

        return calculateCenteredFrame(
            in: screen.visibleFrame,
            defaultWidth: defaultWidth,
            defaultHeight: defaultHeight,
            windowCount: windowCount
        )
    }

    // MARK: - Private Methods

    private func createFallbackFrame(defaultWidth: CGFloat, defaultHeight: CGFloat) -> NSRect {
        let frame = NSRect(
            x: Constants.fallbackPosition,
            y: Constants.fallbackPosition,
            width: max(defaultWidth, Constants.minWidth),
            height: max(defaultHeight, Constants.minHeight)
        )

        logger.debug("Created fallback frame: \\(frame.size.width)x\\(frame.size.height)")
        return frame
    }

    private func calculateCenteredFrame(
        in visibleFrame: NSRect,
        defaultWidth: CGFloat,
        defaultHeight: CGFloat,
        windowCount: Int
    ) -> NSRect {
        let width: CGFloat = max(defaultWidth, Constants.minWidth)
        let height: CGFloat = max(defaultHeight, Constants.minHeight)

        let centerX: CGFloat = visibleFrame.minX + (visibleFrame.width - width) / 2
        let centerY: CGFloat = visibleFrame.minY + (visibleFrame.height - height) / 2

        let offset: CGFloat = CGFloat(windowCount) * Constants.cascadeOffset

        let frame = NSRect(
            x: centerX + offset,
            y: centerY - offset,
            width: width,
            height: height
        )

        return frame.ensureOnScreen()
    }
}
