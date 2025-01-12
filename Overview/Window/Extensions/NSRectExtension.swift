/*
 Window/Extensions/NSRectExtension.swift
 Overview

 Created by William Pierce on 1/7/25.

 Provides screen boundary management functionality for NSRect frames,
 ensuring windows remain visible within screen bounds.
*/

import AppKit

extension NSRect {
    // MARK: - Constants

    private struct Constraints {
        static let minWidth: CGFloat = 60
        static let minHeight: CGFloat = 180
        static let maxWidth: CGFloat = 5120
        static let maxHeight: CGFloat = 2880
        static let minVisiblePortion: CGFloat = 50
        static let defaultScreenWidth: CGFloat = 1440
        static let defaultScreenHeight: CGFloat = 900
    }

    // MARK: - Public Methods

    func ensureOnScreen() -> NSRect {
        let visibleFrames: [NSRect] = NSScreen.screens.map { $0.visibleFrame }

        guard !visibleFrames.isEmpty else {
            return centerOnDefaultScreen()
        }

        let targetScreen: NSScreen = findTargetScreen()
        let adjustedSize: NSSize = calculateAdjustedSize(for: targetScreen)
        let adjustedPosition: NSPoint = calculateAdjustedPosition(
            size: adjustedSize,
            targetFrame: targetScreen.visibleFrame
        )

        return NSRect(origin: adjustedPosition, size: adjustedSize)
    }

    // MARK: - Private Methods

    private func centerOnDefaultScreen() -> NSRect {
        let screenBounds: NSRect =
            NSScreen.main?.frame
            ?? NSRect(
                x: 0,
                y: 0,
                width: Constraints.defaultScreenWidth,
                height: Constraints.defaultScreenHeight
            )

        return NSRect(
            x: (screenBounds.width - width) / 2,
            y: (screenBounds.height - height) / 2,
            width: width,
            height: height
        )
    }

    private func findTargetScreen() -> NSScreen {
        let containingScreen: NSScreen? = NSScreen.screens.first {
            $0.visibleFrame.intersects(self)
        }
        return containingScreen ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func calculateAdjustedSize(for screen: NSScreen) -> NSSize {
        let targetFrame: NSRect = screen.visibleFrame

        // Apply scale factor
        var adjustedWidth: CGFloat = width
        var adjustedHeight: CGFloat = height

        // Constrain dimensions
        let maxWidth: CGFloat = min(targetFrame.width, Constraints.maxWidth)
        let maxHeight: CGFloat = min(targetFrame.height, Constraints.maxHeight)

        adjustedWidth = min(max(Constraints.minWidth, adjustedWidth), maxWidth)
        adjustedHeight = min(max(Constraints.minHeight, adjustedHeight), maxHeight)

        // Reverse scale factor
        return NSSize(
            width: adjustedWidth,
            height: adjustedHeight
        )
    }

    private func calculateAdjustedPosition(size: NSSize, targetFrame: NSRect) -> NSPoint {
        var adjustedX: CGFloat = origin.x
        var adjustedY: CGFloat = origin.y

        // Ensure minimum visibility on x-axis
        if origin.x + size.width < targetFrame.minX + Constraints.minVisiblePortion {
            adjustedX = targetFrame.minX
        } else if origin.x > targetFrame.maxX - Constraints.minVisiblePortion {
            adjustedX = targetFrame.maxX - size.width
        }

        // Ensure minimum visibility on y-axis
        if origin.y + size.height < targetFrame.minY + Constraints.minVisiblePortion {
            adjustedY = targetFrame.minY
        } else if origin.y > targetFrame.maxY - Constraints.minVisiblePortion {
            adjustedY = targetFrame.maxY - size.height
        }

        return NSPoint(x: adjustedX, y: adjustedY)
    }
}
