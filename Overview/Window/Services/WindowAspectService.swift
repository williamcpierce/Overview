/*
 Window/Services/WindowAspectService.swift
 Overview

 Locks preview window resize to the source aspect while still allowing drag and scale.
*/
import AppKit

@MainActor
final class WindowAspectService {
    private let logger = AppLogger.interface

    /// Apply or clear the window aspect lock. Snap size only when the ratio first appears or changes.
    func applyAspectLock(
        for window: NSWindow,
        aspectRatio: CGFloat?,
        snapToRatio: Bool
    ) {
        guard let aspectRatio, aspectRatio > 0, aspectRatio.isFinite else {
            if window.contentAspectRatio != .zero {
                window.contentAspectRatio = .zero
                logger.debug("Cleared preview aspect lock")
            }
            return
        }

        let lock = NSSize(width: aspectRatio, height: 1)
        if window.contentAspectRatio != lock {
            window.contentAspectRatio = lock
            logger.debug("Locked preview aspect ratio to \(String(format: "%.3f", aspectRatio))")
        }

        // Never fight an in-progress user resize; contentAspectRatio already constrains the drag.
        guard snapToRatio, !window.inLiveResize else { return }
        guard let adjusted = adjustedContentSize(for: window, aspectRatio: aspectRatio) else { return }
        window.setContentSize(adjusted)
        logger.debug("Snapped preview size to \(Int(adjusted.width))x\(Int(adjusted.height))")
    }

    private func adjustedContentSize(for window: NSWindow, aspectRatio: CGFloat) -> NSSize? {
        let width = window.frame.width
        let height = window.frame.height
        let desiredHeight = width / aspectRatio
        guard abs(height - desiredHeight) > 1 else { return nil }
        return NSSize(width: width, height: desiredHeight)
    }
}
