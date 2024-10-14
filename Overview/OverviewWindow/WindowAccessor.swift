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
import AppKit

struct WindowAccessor: NSViewRepresentable {
    @Binding var aspectRatio: CGFloat
    @Binding var isEditModeEnabled: Bool
    @ObservedObject var appSettings: AppSettings

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.configureWindow(for: view, with: context)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        updateWindowSize(window)
        updateWindowEditMode(window)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Window Creation and Configuration

    static func createNewWindow(with content: () -> ContentView) -> NSWindow {
        guard let screen = NSScreen.main else { return NSWindow() }
        let screenSize = screen.frame.size
        let windowSize = AppSettings().defaultWindowSize
        let origin = CGPoint(
            x: (screenSize.width - windowSize.width) / 2,
            y: (screenSize.height - windowSize.height) / 2
        )

        let newWindow = NSWindow(
            contentRect: NSRect(origin: origin, size: windowSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newWindow.contentView = NSHostingView(rootView: content())
        configureWindowStyle(newWindow)

        return newWindow
    }

    private static func configureWindowStyle(_ window: NSWindow) {
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.level = .floating
        window.isOpaque = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = false
    }

    // MARK: - Window Configuration Methods

    private func configureWindow(for view: NSView, with context: Context) {
        guard let window = view.window else { return }
        window.delegate = context.coordinator
        configureWindowStyle(window)
        configureWindowSize(window)
        configureWindowAppearance(window)
    }

    private func configureWindowStyle(_ window: NSWindow) {
        window.styleMask = [.borderless, .resizable, .fullSizeContentView]
        window.isMovableByWindowBackground = isEditModeEnabled
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.level = .floating
        window.isOpaque = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = false
    }

    private func configureWindowSize(_ window: NSWindow) {
        let size = NSSize(width: appSettings.defaultWindowWidth, height: appSettings.defaultWindowHeight)
        window.setContentSize(size)
        window.contentMinSize = size
        window.contentAspectRatio = size
    }

    private func configureWindowAppearance(_ window: NSWindow) {
        window.backgroundColor = .clear
        window.styleMask.insert(.fullSizeContentView)

        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    // MARK: - Window Update Methods

    private func updateWindowSize(_ window: NSWindow) {
        let currentSize = window.frame.size
        let newHeight = currentSize.width / CGFloat(aspectRatio)
        window.setContentSize(NSSize(width: currentSize.width, height: newHeight))
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)
    }

    private func updateWindowEditMode(_ window: NSWindow) {
        window.isMovableByWindowBackground = isEditModeEnabled
        window.isMovable = isEditModeEnabled
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSWindowDelegate {
        var parent: WindowAccessor

        init(_ parent: WindowAccessor) {
            self.parent = parent
        }

        func windowDidResize(_ notification: Notification) {
            // Aspect ratio is maintained by the window itself
        }

        func windowDidChangeScreen(_ notification: Notification) {
            if let window = notification.object as? NSWindow {
                window.center()
            }
        }
    }
}
