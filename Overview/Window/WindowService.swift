/*
 Window/WindowService.swift
 Overview

 Created by William Pierce on 1/5/25.

 Manages window creation, state persistence, and restoration for preview windows.
*/

import SwiftUI

final class WindowService {
    // MARK: - Dependencies
    
    private let settings: AppSettings
    private let previewManager: PreviewManager
    private let sourceManager: SourceManager
    private let stateManager: WindowStateManager
    private let logger = AppLogger.interface
    
    init(settings: AppSettings, preview: PreviewManager, source: SourceManager) {
        self.settings = settings
        self.previewManager = preview
        self.sourceManager = source
        self.stateManager = WindowStateManager()
    }
    
    // MARK: - Window Management
    
    func createPreviewWindow(at frame: NSRect? = nil) {
        let defaultFrame = NSRect(
            x: 100, y: 100,
            width: settings.previewDefaultWidth,
            height: settings.previewDefaultHeight
        )
        
        let window = NSWindow(
            contentRect: frame ?? defaultFrame,
            styleMask: [.fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        configureWindow(window)
        setupWindowContent(window)
        window.makeKeyAndOrderFront(nil)
        
        logger.info("Created new preview window")
    }
    
    func closeAllPreviewWindows() {
        saveWindowStates()
        NSApplication.shared.windows.forEach { window in
            if window.contentView?.ancestorOrSelf(ofType: NSHostingView<ContentView>.self) != nil {
                window.close()
            }
        }
        logger.info("Closed all preview windows")
    }
    
    // MARK: - State Management
    
    func saveWindowStates() {
        stateManager.saveWindowStates()
    }
    
    func restoreWindowStates() {
        stateManager.restoreWindows { [weak self] frame in
            self?.createPreviewWindow(at: frame)
        }
    }
    
    // MARK: - Private Methods
    
    private func configureWindow(_ window: NSWindow) {
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.level = .statusBar + 1
        window.collectionBehavior = [.fullScreenAuxiliary]
    }
    
    private func setupWindowContent(_ window: NSWindow) {
        let contentView = ContentView(
            appSettings: settings,
            previewManager: previewManager,
            sourceManager: sourceManager
        )
        window.contentView = NSHostingView(rootView: contentView)
    }
}
