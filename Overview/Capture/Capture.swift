/*
 Capture/Capture.swift
 Overview

 Created by William Pierce on 12/6/24.
*/

import SwiftUI

struct Capture: NSViewRepresentable {
    let frame: CapturedFrame
    private let logger = AppLogger.capture

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        logger.debug("Created layer-backed NSView for frame rendering")
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let surfaceContent = frame.surface else {
            logger.warning("Attempted to update view with invalid surface")
            return
        }

        let renderLayer = CALayer()
        renderLayer.contents = surfaceContent
        renderLayer.contentsScale = frame.contentScale
        renderLayer.bounds = frame.contentRect

        // Critical section: Layer assignment must be atomic to prevent screen tearing
        nsView.layer = renderLayer
    }
}
