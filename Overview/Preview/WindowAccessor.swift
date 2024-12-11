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

    private let updateDebounceInterval: TimeInterval = 0.1

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            guard let window = view.window else { return }

            window.styleMask = [.fullSizeContentView]
            window.hasShadow = false
            window.backgroundColor = .clear
            window.isMovableByWindowBackground = true

            window.collectionBehavior.insert(.fullScreenAuxiliary)

            let size = NSSize(
                width: appSettings.defaultWindowWidth,
                height: appSettings.defaultWindowHeight
            )
            window.setContentSize(size)
            window.contentMinSize = size
            window.contentAspectRatio = size
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + updateDebounceInterval) {
            updateEditModeProperties(for: window)
            updateWindowManagement(for: window)
            updateWindowSize(for: window)
        }
    }

    private func updateEditModeProperties(for window: NSWindow) {
        window.styleMask =
            isEditModeEnabled ? [.fullSizeContentView, .resizable] : [.fullSizeContentView]
        window.isMovable = isEditModeEnabled
        window.level =
            isEditModeEnabled && appSettings.enableEditModeAlignment
            ? .floating
            : .statusBar + 1
    }

    private func updateWindowManagement(for window: NSWindow) {
        if appSettings.managedByMissionControl {
            window.collectionBehavior.insert(.managed)
        } else {
            window.collectionBehavior.remove(.managed)
        }
    }

    private func updateWindowSize(for window: NSWindow) {
        let currentSize = window.frame.size
        let newHeight = currentSize.width / aspectRatio

        if abs(currentSize.height - newHeight) > 1.0 {
            window.setContentSize(NSSize(width: currentSize.width, height: newHeight))
            window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)
        }
    }
}
