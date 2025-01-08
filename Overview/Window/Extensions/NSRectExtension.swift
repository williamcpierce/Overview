/*
 Window/Extensions/NSRectExtension.swift
 Overview

 Created by William Pierce on 1/07/25.

 Provides screen boundary management functionality for NSRect frames,
 ensuring windows remain visible within screen bounds.
*/

import AppKit

extension NSRect {
    func ensureOnScreen() -> NSRect {
        // Get the visible frame of all screens
        let screens: [NSScreen] = NSScreen.screens
        let visibleFrames: [NSRect] = screens.map { $0.visibleFrame }

        // If no screens are available, return centered frame on main screen bounds
        guard !visibleFrames.isEmpty else {
            let screenBounds: NSRect =
                NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            return NSRect(
                x: (screenBounds.width - width) / 2,
                y: (screenBounds.height - height) / 2,
                width: width,
                height: height
            )
        }

        // First try to find the screen this window belongs to
        let containingScreen: NSScreen? = screens.first { $0.visibleFrame.intersects(self) }
        let targetScreen: NSScreen = containingScreen ?? NSScreen.main ?? screens[0]
        let targetFrame: NSRect = targetScreen.visibleFrame

        var adjustedFrame: CGRect = self

        // Account for screen scale factor
        let scaleFactor: CGFloat = targetScreen.backingScaleFactor
        adjustedFrame.size.width *= scaleFactor
        adjustedFrame.size.height *= scaleFactor

        // Ensure minimum and maximum dimensions
        let minWidth: CGFloat = 200
        let minHeight: CGFloat = 150
        let maxWidth: CGFloat = min(targetFrame.width, 2000)  // Prevent excessive sizes
        let maxHeight: CGFloat = min(targetFrame.height, 1500)

        adjustedFrame.size.width = min(max(minWidth, adjustedFrame.size.width), maxWidth)
        adjustedFrame.size.height = min(max(minHeight, adjustedFrame.size.height), maxHeight)

        // Adjust for screen scale factor
        adjustedFrame.size.width /= scaleFactor
        adjustedFrame.size.height /= scaleFactor

        // Ensure the window is at least partially visible
        let minVisiblePortion: CGFloat = 50

        // Adjust x-position, accounting for screen bounds
        if adjustedFrame.maxX < targetFrame.minX + minVisiblePortion {
            adjustedFrame.origin.x = targetFrame.minX
        } else if adjustedFrame.minX > targetFrame.maxX - minVisiblePortion {
            adjustedFrame.origin.x = targetFrame.maxX - adjustedFrame.width
        }

        // Adjust y-position, accounting for menu bar and dock
        if adjustedFrame.maxY < targetFrame.minY + minVisiblePortion {
            adjustedFrame.origin.y = targetFrame.minY
        } else if adjustedFrame.minY > targetFrame.maxY - minVisiblePortion {
            adjustedFrame.origin.y = targetFrame.maxY - adjustedFrame.height
        }

        return adjustedFrame
    }
}
