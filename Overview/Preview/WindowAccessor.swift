/*
 WindowAccessor.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    @Binding var aspectRatio: CGFloat
    @Binding var isEditModeEnabled: Bool
    @ObservedObject var appSettings: AppSettings
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                // Set basic window properties
                window.styleMask = [.fullSizeContentView]
                window.hasShadow = false
                window.backgroundColor = .clear
                window.isMovableByWindowBackground = true
                window.collectionBehavior.insert(.fullScreenAuxiliary)
                
                // Set initial size
                let size = NSSize(width: appSettings.defaultWindowWidth, height: appSettings.defaultWindowHeight)
                window.setContentSize(size)
                window.contentMinSize = size
                window.contentAspectRatio = size
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }

        // Debounce window updates using async dispatch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Update edit mode settings
            window.styleMask = isEditModeEnabled ? [.fullSizeContentView, .resizable] : [.fullSizeContentView]
            window.isMovable = isEditModeEnabled
            window.level = isEditModeEnabled && appSettings.enableEditModeAlignment ? .floating : .statusBar + 1
            
            // Update window management
            if appSettings.managedByMissionControl {
                window.collectionBehavior.insert(.managed)
            } else {
                window.collectionBehavior.remove(.managed)
            }
            
            // Update window size to maintain aspect ratio
            let currentSize = window.frame.size
            let newHeight = currentSize.width / aspectRatio
            if abs(currentSize.height - newHeight) > 1.0 {
                window.setContentSize(NSSize(width: currentSize.width, height: newHeight))
                window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)
            }
        }
    }
}
