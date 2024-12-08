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
    // MARK: - Properties
    @Binding var aspectRatio: CGFloat
    @Binding var isEditModeEnabled: Bool
    @ObservedObject var appSettings: AppSettings
    
    // MARK: - NSViewRepresentable Methods
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.configureWindow(for: view, with: context)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        updateWindowBehavior(window)
        updateWindowSize(window)
    }
    
    // MARK: - Window Configuration
    private func configureWindow(for view: NSView, with context: Context) {
        guard let window = view.window else { return }
        configureWindowAppearance(window)
        configureWindowBehavior(window)
        configureWindowSize(window)
    }
    
    private func configureWindowAppearance(_ window: NSWindow) {
        window.styleMask = [.hudWindow]
        window.hasShadow = false
        window.backgroundColor = .clear
    }

    private func configureWindowBehavior(_ window: NSWindow) {
        window.isMovableByWindowBackground = true
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        updateWindowBehavior(window)
    }
    
    private func configureWindowSize(_ window: NSWindow) {
        let size = NSSize(
            width: appSettings.defaultWindowWidth,
            height: appSettings.defaultWindowHeight
        )
        window.setContentSize(size)
        window.contentMinSize = size
        window.contentAspectRatio = size
    }
    
    // MARK: - Window Updates
    private func updateWindowBehavior(_ window: NSWindow) {
        if isEditModeEnabled {
            window.styleMask.insert(.resizable)
            window.isMovable = true
        } else {
            window.styleMask.remove(.resizable)
            window.isMovable = false
        }
        
        if isEditModeEnabled && appSettings.enableEditModeAlignment {
            window.level = .floating
        } else {
            window.level = .statusBar + 1
        }
        
        if appSettings.managedByMissionControl {
            window.collectionBehavior.insert(.managed)
        } else {
            window.collectionBehavior.remove(.managed)
        }
    }
    
    private func updateWindowSize(_ window: NSWindow) {
        let currentSize = window.frame.size
        let newHeight = currentSize.width / CGFloat(aspectRatio)
        window.setContentSize(NSSize(width: currentSize.width, height: newHeight))
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)
    }
}
