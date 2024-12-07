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

struct Capture: NSViewRepresentable {
    let frame: CapturedFrame

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let surface = frame.surface else { return }

        let layer = CALayer()
        layer.contents = surface
        layer.contentsScale = frame.contentScale
        layer.bounds = frame.contentRect

        nsView.layer = layer
    }
}
