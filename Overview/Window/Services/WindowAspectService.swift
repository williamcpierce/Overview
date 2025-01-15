/*
 Window/Services/WindowAspectService.swift
 Overview

 Created by William Pierce on 1/13/25.

 Manages window aspect ratio calculations and adjustments.
*/

import AppKit

final class WindowAspectService {
    // Constants
    private struct Constants {
        static let minHeightDifference: CGFloat = 1.0
    }

    // Dependencies
    private let logger = AppLogger.interface

    func synchronizeAspectRatio(
        for window: NSWindow,
        aspectRatio: CGFloat,
        isCapturing: Bool
    ) {
        guard isCapturing,
            aspectRatio != 0,
            let adjustedSize: NSSize = calculateAdjustedSize(
                for: window,
                aspectRatio: aspectRatio
            )
        else {
            return
        }

        window.setContentSize(adjustedSize)
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)

        logger.info("Window resized: \\(Int(adjustedSize.width))x\\(Int(adjustedSize.height))")
    }

    // MARK: - Private Methods

    private func calculateAdjustedSize(
        for window: NSWindow,
        aspectRatio: CGFloat
    ) -> NSSize? {
        let windowWidth: CGFloat = window.frame.width
        let windowHeight: CGFloat = window.frame.height
        let desiredHeight: CGFloat = windowWidth / aspectRatio

        let heightDifference: CGFloat = abs(windowHeight - desiredHeight)
        guard heightDifference > Constants.minHeightDifference else { return nil }

        return NSSize(width: windowWidth, height: desiredHeight)
    }
}
