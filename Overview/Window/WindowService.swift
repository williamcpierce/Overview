import SwiftUI

final class WindowService {
    // MARK: - Dependencies
    private let settings: AppSettings
    private let previewManager: PreviewManager
    private let sourceManager: SourceManager
    private let stateManager: WindowStateManager
    private let logger = AppLogger.interface
    
    // Track active windows
    private var activeWindows: Set<NSWindow> = []
    
    init(settings: AppSettings, preview: PreviewManager, source: SourceManager) {
        self.settings = settings
        self.previewManager = preview
        self.sourceManager = source
        self.stateManager = WindowStateManager()
        logger.debug("Window service initialized")
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
            styleMask: [.fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.delegate = WindowDelegate(windowService: self)
        configureWindow(window)
        setupWindowContent(window)
        
        // Track the window
        activeWindows.insert(window)
        
        window.makeKeyAndOrderFront(nil)
        logger.info("Created new preview window")
    }
    
    func closeAllPreviewWindows() {
        // Create a copy of the set to avoid modification during iteration
        let windowsToClose = activeWindows
        
        for window in windowsToClose {
            closeWindow(window)
        }
        
        logger.info("Closed all preview windows")
    }
    
    func closeWindow(_ window: NSWindow) {
        saveWindowState(for: window)
        activeWindows.remove(window)
        window.close()
    }
    
    // MARK: - State Management
    
    func saveWindowStates() {
        stateManager.saveWindowStates()
    }
    
    func saveWindowState(for window: NSWindow) {
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

// Window delegate to handle window closing
private class WindowDelegate: NSObject, NSWindowDelegate {
    private weak var windowService: WindowService?
    
    init(windowService: WindowService) {
        self.windowService = windowService
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windowService?.saveWindowState(for: window)
    }
}
