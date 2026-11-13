/*
 Window/PreviewWindow.swift
 Overview

 Created by William Pierce on 11/12/26.

 A preview window that may be placed anywhere on the physical display,
 including the menu bar and Dock regions, which are hidden while the
 captured game window runs.
*/

import AppKit

final class PreviewWindow: NSWindow {
    // Constants
    private struct Constraints {
        static let minVisiblePortion: CGFloat = 50
    }

    // AppKit keeps a window's top edge below the menu bar during
    // interactive moves and resizes. Previews have no titlebar and are
    // expected to cover the full display, so clamp to the physical
    // desktop bounds instead while still preventing windows from being
    // lost off-display.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        let desktop: NSRect = NSScreen.screens.reduce(into: NSRect.null) {
            $0 = $0.union($1.frame)
        }

        guard !desktop.isNull, !desktop.isEmpty else {
            return frameRect
        }

        var constrained: NSRect = frameRect
        constrainOrigin(
            &constrained.origin.x,
            extent: constrained.width,
            low: desktop.minX,
            high: desktop.maxX
        )
        constrainOrigin(
            &constrained.origin.y,
            extent: constrained.height,
            low: desktop.minY,
            high: desktop.maxY
        )

        return constrained
    }

    // MARK: - Private Methods

    private func constrainOrigin(
        _ origin: inout CGFloat,
        extent: CGFloat,
        low: CGFloat,
        high: CGFloat
    ) {
        if extent <= high - low {
            origin = min(max(origin, low), high - extent)
        } else if origin + extent < low + Constraints.minVisiblePortion {
            origin = low
        } else if origin > high - Constraints.minVisiblePortion {
            origin = high - extent
        }
    }
}
