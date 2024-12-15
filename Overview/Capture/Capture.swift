/*
 Capture.swift
 Overview

 Created by William Pierce on 12/6/24.

 Provides efficient rendering of captured window content using Core Animation layers,
 handling display scaling and frame updates with minimal overhead. The component
 serves as the bridge between IOSurface capture data and SwiftUI rendering.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

/// Renders captured window content using a high-performance Core Animation layer
///
/// Key responsibilities:
/// - Converts CapturedFrame data into a renderable CALayer representation
/// - Maintains proper content scaling across varying display densities
/// - Handles dynamic frame updates with minimal performance impact
/// - Ensures proper memory management of IOSurface resources
///
/// Coordinates with:
/// - CaptureEngine: Receives frame data and scaling information
/// - PreviewView: Integrates into the SwiftUI view hierarchy
/// - PreviewAccessor: Coordinates preview window dimensions and scaling
struct Capture: NSViewRepresentable {
    // MARK: - Properties

    /// Current frame data containing surface and layout information
    /// - Note: Updates frequently (up to screen refresh rate)
    let frame: CapturedFrame

    // MARK: - NSViewRepresentable Implementation

    /// Creates the underlying NSView with layer support enabled
    ///
    /// Flow:
    /// 1. Creates base NSView instance
    /// 2. Enables layer backing for Core Animation
    /// 3. Returns configured view for layer updates
    ///
    /// - Parameter context: View creation context
    /// - Returns: Layer-backed NSView for frame rendering
    /// - Important: View must be layer-backed for proper rendering
    func makeNSView(context: Context) -> NSView {
        // Context: Using NSView for direct layer access provides
        // better performance with frequent frame updates
        let view = NSView()
        view.wantsLayer = true

        AppLogger.capture.debug("Created layer-backed NSView for frame rendering")
        return view
    }

    /// Updates the view's layer with new frame content
    ///
    /// Flow:
    /// 1. Validates IOSurface availability
    /// 2. Creates CALayer with proper scaling
    /// 3. Updates view's backing layer
    ///
    /// - Parameters:
    ///   - nsView: View to update
    ///   - context: Update context
    /// - Important: Layer updates must occur on main thread
    /// - Warning: Must ensure proper IOSurface lifecycle
    func updateNSView(_ nsView: NSView, context: Context) {
        // Context: Direct layer replacement provides better performance
        // than updating existing layer properties
        guard let surface = frame.surface else {
            AppLogger.capture.warning("Attempted to update view with invalid surface")
            return
        }

        let layer = CALayer()

        // Configure layer for optimal rendering
        layer.contents = surface
        layer.contentsScale = frame.contentScale
        layer.bounds = frame.contentRect

        // WARNING: Layer replacement must be atomic to prevent tearing
        nsView.layer = layer
    }
}
