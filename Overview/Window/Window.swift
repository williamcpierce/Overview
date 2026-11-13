/*
 Window/Window.swift
 Overview

 Created by William Pierce on 1/5/25.
*/

import Foundation
import ScreenCaptureKit

struct Window: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    var source: WindowSource?

    var frame: NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }

    init(frame: NSRect, source: WindowSource? = nil) {
        self.x = frame.origin.x
        self.y = frame.origin.y
        self.width = frame.width
        self.height = frame.height
        self.source = source
    }
}

// Snapshot of the source window bound to a preview window, used to
// reacquire the same source window when a layout is applied.
struct WindowSource: Codable, Equatable {
    var title: String?
    var bundleID: String?
    var windowID: UInt32?

    init(source: SCWindow) {
        self.title = source.title
        self.bundleID = source.owningApplication?.bundleIdentifier
        self.windowID = source.windowID
    }
}
