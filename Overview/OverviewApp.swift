/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 The main application entry point that configures and coordinates core services,
 manages the application lifecycle, and sets up the primary user interface.
*/

import SwiftUI

extension NSView {
    func ancestorOrSelf<T>(ofType type: T.Type) -> T? {
        if let self = self as? T {
            return self
        }
        return superview?.ancestorOrSelf(ofType: type)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let windowStateManager: WindowStateManager
    let logger = AppLogger.interface
    
    init(windowStateManager: WindowStateManager) {
        self.windowStateManager = windowStateManager
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc func applicationWillTerminate(_ notification: Notification) {
        logger.debug("=== Application Termination Sequence ===")
        logger.debug("Pre-save window state:")
        windowStateManager.debugCurrentState()
        
        windowStateManager.saveWindowStates()
        
        logger.debug("Post-save window state:")
        windowStateManager.debugCurrentState()
        logger.info("Application terminating, saved window states")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

@main
struct OverviewApp: App {
    @StateObject private var appSettings: AppSettings
    @StateObject private var windowManager: WindowManager
    @StateObject private var previewManager: PreviewManager
    @StateObject private var hotkeyManager: HotkeyManager
    
    private let windowStateManager: WindowStateManager
    private let appInitializer: AppInitializer
    private let logger = AppLogger.interface
    
    init() {
        logger.debug("Initializing core application services")
        
        // Initialize all services first
        let settings = AppSettings()
        let window = WindowManager(appSettings: settings)
        let preview = PreviewManager(windowManager: window)
        let hotkey = HotkeyManager(appSettings: settings, windowManager: window)
        let stateManager = WindowStateManager()
        
        // Create StateObjects
        self._appSettings = StateObject(wrappedValue: settings)
        self._windowManager = StateObject(wrappedValue: window)
        self._previewManager = StateObject(wrappedValue: preview)
        self._hotkeyManager = StateObject(wrappedValue: hotkey)
        self.windowStateManager = stateManager
        
        // Create app initializer
        self.appInitializer = AppInitializer(
            windowStateManager: stateManager,
            appSettings: settings,
            previewManager: preview,
            windowManager: window
        )
        
        // Set up app delegate for termination handling only
        if NSApplication.shared.delegate == nil {
            let delegate = AppDelegate(windowStateManager: stateManager)
            NSApplication.shared.delegate = delegate
            logger.debug("AppDelegate registered with NSApplication")
        }
        
        // Start initialization sequence
        self.appInitializer.initializeApp()
        
        logger.info("Application services initialized successfully")
    }
    
    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
        .commands {
            CommandGroup(before: .newItem) {
                Button("New Preview Window") {
                    openNewWindow(
                        appSettings: appSettings,
                        previewManager: previewManager,
                        windowManager: windowManager
                    )
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Close All Windows") {
                    closeAllWindows(windowStateManager: windowStateManager)
                }
                .keyboardShortcut("w", modifiers: [.command, .option])
            }
            
            CommandMenu("Edit") {
                Toggle("Edit Mode", isOn: $previewManager.editModeEnabled)
            }
        }
        
        Settings {
            SettingsView(
                appSettings: appSettings,
                windowManager: windowManager
            )
        }
    }
}

// MARK: - Window Management Functions

private func openNewWindow(at frame: NSRect? = nil, appSettings: AppSettings, previewManager: PreviewManager, windowManager: WindowManager) {
    let defaultFrame = NSRect(
        x: 100, y: 100,
        width: appSettings.defaultWindowWidth,
        height: appSettings.defaultWindowHeight
    )
    
    let window = NSWindow(
        contentRect: frame ?? defaultFrame,
        styleMask: [.fullSizeContentView],
        backing: .buffered,
        defer: false
    )
    
    let contentView = ContentView(
        appSettings: appSettings,
        previewManager: previewManager,
        windowManager: windowManager
    )
    
    window.contentView = NSHostingView(rootView: contentView)
    window.backgroundColor = .clear
    window.hasShadow = false
    window.isMovableByWindowBackground = true
    window.level = .statusBar + 1
    window.collectionBehavior = [.fullScreenAuxiliary]
    window.makeKeyAndOrderFront(nil)
    
    AppLogger.interface.info("Created new preview window")
}

private func closeAllWindows(windowStateManager: WindowStateManager) {
    windowStateManager.saveWindowStates()
    NSApplication.shared.windows.forEach { window in
        if window.contentView?.ancestorOrSelf(ofType: NSHostingView<ContentView>.self) != nil {
            window.close()
            AppLogger.interface.debug("Closed window: \(window)")
        }
    }
    AppLogger.interface.info("Closed all preview windows")
}

// MARK: - Window State Manager

class WindowStateManager: ObservableObject {
    private let logger = AppLogger.interface
    private let windowPositionsKey = "StoredWindowPositions"
    
    struct WindowState: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        
        var debugDescription: String {
            return "WindowState(x: \(x), y: \(y), width: \(width), height: \(height))"
        }
    }
    
    func saveWindowStates() {
        logger.debug("Starting window state save operation")
        var positions: [WindowState] = []
        
        let allWindows = NSApplication.shared.windows
        logger.debug("Total windows found: \(allWindows.count)")
        
        allWindows.forEach { window in
            // Check if window is one of our preview windows
            if let hostingView = window.contentView?.ancestorOrSelf(ofType: NSHostingView<ContentView>.self) {
                let frame = window.frame
                let state = WindowState(
                    x: frame.origin.x,
                    y: frame.origin.y,
                    width: frame.width,
                    height: frame.height
                )
                positions.append(state)
                logger.debug("Saving window state: \(state.debugDescription)")
            }
        }
        
        do {
            let data = try JSONEncoder().encode(positions)
            UserDefaults.standard.set(data, forKey: windowPositionsKey)
            logger.info("Successfully saved \(positions.count) window positions")
            
            // Verify save
            if let verifyData = UserDefaults.standard.data(forKey: windowPositionsKey) {
                let verifyPositions = try JSONDecoder().decode([WindowState].self, from: verifyData)
                logger.debug("Verified save - can read back \(verifyPositions.count) positions")
            }
        } catch {
            logger.logError(error, context: "Failed to encode window positions")
        }
    }
    
    func restoreWindows(using createWindow: (NSRect) -> Void) {
        logger.debug("Starting window restoration process")
        
        // Check if we have saved data
        guard let data = UserDefaults.standard.data(forKey: windowPositionsKey) else {
            logger.debug("No window position data found in UserDefaults")
            return
        }
        
        logger.debug("Found saved window data: \(data.count) bytes")
        
        do {
            let positions = try JSONDecoder().decode([WindowState].self, from: data)
            logger.info("Successfully decoded \(positions.count) window positions")
            
            for (index, position) in positions.enumerated() {
                logger.debug("Restoring window \(index + 1): \(position.debugDescription)")
                let frame = NSRect(
                    x: position.x,
                    y: position.y,
                    width: position.width,
                    height: position.height
                )
                createWindow(frame)
            }
            
            // Verify restoration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                let restoredCount = NSApplication.shared.windows.filter { window in
                    window.contentView?.ancestorOrSelf(ofType: NSHostingView<ContentView>.self) != nil
                }.count
                self?.logger.debug("Post-restoration window count: \(restoredCount)")
            }
            
        } catch {
            logger.logError(error, context: "Failed to decode window positions")
        }
    }
    
    // Utility method to check current state
    func debugCurrentState() {
        logger.debug("=== Current Window State ===")
        if let data = UserDefaults.standard.data(forKey: windowPositionsKey) {
            logger.debug("Saved data size: \(data.count) bytes")
            do {
                let positions = try JSONDecoder().decode([WindowState].self, from: data)
                logger.debug("Saved positions count: \(positions.count)")
                positions.forEach { position in
                    logger.debug("Saved position: \(position.debugDescription)")
                }
            } catch {
                logger.logError(error, context: "Failed to decode saved positions during debug")
            }
        } else {
            logger.debug("No saved window positions found")
        }
        
        let currentWindows = NSApplication.shared.windows.filter { window in
            window.contentView?.ancestorOrSelf(ofType: NSHostingView<ContentView>.self) != nil
        }
        logger.debug("Current preview windows count: \(currentWindows.count)")
        currentWindows.forEach { window in
            logger.debug("Current window frame: \(window.frame)")
        }
        logger.debug("========================")
    }
}

class AppInitializer {
    private let logger = AppLogger.interface
    private let windowStateManager: WindowStateManager
    private let appSettings: AppSettings
    private let previewManager: PreviewManager
    private let windowManager: WindowManager
    
    init(windowStateManager: WindowStateManager,
         appSettings: AppSettings,
         previewManager: PreviewManager,
         windowManager: WindowManager) {
        self.windowStateManager = windowStateManager
        self.appSettings = appSettings
        self.previewManager = previewManager
        self.windowManager = windowManager
    }
    
    func initializeApp() {
        logger.debug("Starting delayed initialization sequence")
        DispatchQueue.main.async { [weak self] in
            self?.restoreWindows()
        }
    }
    
    private func restoreWindows() {
        logger.debug("=== Beginning Window Restoration ===")
        windowStateManager.debugCurrentState()
        
        windowStateManager.restoreWindows { frame in
            logger.debug("Restoring window at frame: \(frame)")
            openNewWindow(
                at: frame,
                appSettings: self.appSettings,
                previewManager: self.previewManager,
                windowManager: self.windowManager
            )
        }
        
        // Verify restoration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.logger.debug("=== Post-Restoration State ===")
            self?.windowStateManager.debugCurrentState()
        }
    }
}
