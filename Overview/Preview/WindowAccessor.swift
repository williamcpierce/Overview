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
                window.styleMask = [.hudWindow]
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
        
        // Update edit mode settings
        window.styleMask = isEditModeEnabled ? [.hudWindow, .resizable] : [.hudWindow]
        window.isMovable = isEditModeEnabled
        window.level = isEditModeEnabled && appSettings.enableEditModeAlignment ? .floating : .statusBar + 1
        
        // Update window management
        if appSettings.managedByMissionControl {
            window.collectionBehavior.insert(.managed)
        } else {
            window.collectionBehavior.remove(.managed)
        }
        
        // Update window size
        let width = window.frame.size.width
        let height = width / aspectRatio
        window.setContentSize(NSSize(width: width, height: height))
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)
    }
}
