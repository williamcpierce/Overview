/*
 Capture.swift
 Overview

 Created by William Pierce on 12/6/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Displays captured window content using a Core Animation layer
///
/// Key responsibilities:
/// - Converts CapturedFrame data into a renderable CALayer
/// - Maintains proper content scaling across display densities
///
/// Coordinates with:
/// - CaptureEngine: Receives frame data including IOSurface and scaling information
/// - PreviewView: Parent view that manages capture lifecycle and window interactions
struct Capture: NSViewRepresentable {
    let frame: CapturedFrame

    /// Creates the underlying NSView with layer support enabled
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        return view
    }

    /// Updates the view's layer with new frame content
    ///
    /// Flow:
    /// 1. Extracts IOSurface from the captured frame
    /// 2. Configures layer properties for proper scaling
    /// 3. Updates the view's backing layer
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let surface = frame.surface else { return }

        let layer = CALayer()
        layer.contents = surface
        layer.contentsScale = frame.contentScale
        layer.bounds = frame.contentRect

        nsView.layer = layer
    }
}
