/*
 ContentView.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var windowManager: WindowManager
    @Binding var isEditModeEnabled: Bool
    @ObservedObject var appSettings: AppSettings
    @State private var captureManagerId: UUID?
    @State private var showingSelection = true
    @State private var selectedWindowSize: CGSize?
    @State private var aspectRatio: CGFloat = 1.5  // Default aspect ratio

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if showingSelection {
                    selectionView
                } else {
                    CapturePreviewContent()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .aspectRatio(aspectRatio, contentMode: .fit)
        }
        .background(
            WindowAccessor(aspectRatio: $aspectRatio, isEditModeEnabled: $isEditModeEnabled, appSettings: appSettings)
        )
        .onAppear(perform: createCaptureManager)
        .onDisappear(perform: removeCaptureManager)
        .onChange(of: selectedWindowSize) {
            if let size = selectedWindowSize {
                aspectRatio = size.width / size.height
            }
        }
    }

    private var selectionView: some View {
        SelectionView(
            windowManager: windowManager,
            captureManagerId: $captureManagerId,
            showingSelection: $showingSelection,
            selectedWindowSize: $selectedWindowSize,
            appSettings: appSettings
        )
        .padding(.vertical, 20)
        .background(Color.black.opacity(0.9))
        .transition(.opacity)
        .overlay(
            InteractionOverlay(
                isEditModeEnabled: $isEditModeEnabled,
                isBringToFrontEnabled: false,
                bringToFrontAction: {},
                toggleEditModeAction: { isEditModeEnabled.toggle() }
            )
        )
        .frame(minWidth: appSettings.defaultWindowWidth, minHeight: appSettings.defaultWindowHeight)
    }

    @ViewBuilder
    private func CapturePreviewContent() -> some View {
        if let id = captureManagerId, let captureManager = windowManager.captureManagers[id] {
            CapturePreviewView(
                captureManager: captureManager,
                isEditModeEnabled: $isEditModeEnabled,
                opacity: appSettings.opacity
            )
            .background(Color.clear)
        } else {
            noCaptureManagerView
        }
    }

    private var noCaptureManagerView: some View {
        VStack {
            Text("No capture manager found")
                .foregroundColor(.red)
            Button("Retry", action: createCaptureManager)
                .padding()
        }
    }

    private func createCaptureManager() {
        captureManagerId = windowManager.createNewCaptureManager()
    }

    private func removeCaptureManager() {
        if let id = captureManagerId {
            windowManager.removeCaptureManager(id: id)
        }
    }

    private func updateAspectRatio(_ size: CGSize?) {
        if let size = size {
            aspectRatio = size.width / size.height
        }
    }
}

struct CapturePreviewView: View {
    @ObservedObject var captureManager: ScreenCaptureManager
    @Binding var isEditModeEnabled: Bool
    let opacity: Double

    var body: some View {
        Group {
            if let frame = captureManager.capturedFrame {
                CapturePreview(frame: frame)
                    .opacity(opacity)
                    .overlay(
                        InteractionOverlay(
                            isEditModeEnabled: $isEditModeEnabled,
                            isBringToFrontEnabled: true,
                            bringToFrontAction: {
                                captureManager.focusWindow(isEditModeEnabled: isEditModeEnabled)
                            },
                            toggleEditModeAction: { isEditModeEnabled.toggle() }
                        )
                    )
            } else {
                Text("No capture available")
                    .opacity(opacity)
            }
        }
        .onAppear(perform: startCapture)
        .onDisappear(perform: stopCapture)
    }

    private func startCapture() {
        Task {
            await captureManager.startCapture()
        }
    }

    private func stopCapture() {
        Task {
            await captureManager.stopCapture()
        }
    }
}

struct CapturePreview: NSViewRepresentable {
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

struct InteractionOverlay: NSViewRepresentable {
    @Binding var isEditModeEnabled: Bool
    var isBringToFrontEnabled: Bool
    var bringToFrontAction: () -> Void
    var toggleEditModeAction: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = InteractionView()
        view.isEditModeEnabled = isEditModeEnabled
        view.isBringToFrontEnabled = isBringToFrontEnabled
        view.bringToFrontAction = bringToFrontAction
        view.toggleEditModeAction = toggleEditModeAction

        let menu = createContextMenu(for: view)
        view.menu = menu

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? InteractionView {
            view.isEditModeEnabled = isEditModeEnabled
            view.updateEditModeMenuItem()
        }
    }

    private func createContextMenu(for view: InteractionView) -> NSMenu {
        let menu = NSMenu()

        let editModeItem = NSMenuItem(
            title: "Edit Mode", action: #selector(InteractionView.toggleEditMode(_:)),
            keyEquivalent: "")
        editModeItem.target = view
        menu.addItem(editModeItem)

        menu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(
            title: "Close Window", action: #selector(NSWindow.close), keyEquivalent: "")
        closeItem.target = nil
        menu.addItem(closeItem)

        view.editModeMenuItem = editModeItem

        return menu
    }

    class InteractionView: NSView {
        var isEditModeEnabled = false {
            didSet { updateEditModeMenuItem() }
        }
        var isBringToFrontEnabled: Bool = false
        var bringToFrontAction: (() -> Void)?
        var toggleEditModeAction: (() -> Void)?
        weak var editModeMenuItem: NSMenuItem?

        override func mouseDown(with event: NSEvent) {
            if !isEditModeEnabled && isBringToFrontEnabled {
                bringToFrontAction?()
            } else {
                super.mouseDown(with: event)
            }
        }

        override func rightMouseDown(with event: NSEvent) {
            super.rightMouseDown(with: event)
        }

        @objc func toggleEditMode(_ sender: Any?) {
            toggleEditModeAction?()
        }

        func updateEditModeMenuItem() {
            editModeMenuItem?.state = isEditModeEnabled ? .on : .off
        }
    }
}
