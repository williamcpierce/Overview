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
    private let windowStateManager: WindowStateManager
    private let logger = AppLogger.interface

    init(windowStateManager: WindowStateManager) {
        self.windowStateManager = windowStateManager
        super.init()
        configureTerminationHandler()
    }

    private func configureTerminationHandler() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc func applicationWillTerminate(_ notification: Notification) {
        windowStateManager.saveWindowStates()
        logger.info("Application terminating, window states saved")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

@main
struct OverviewApp: App {
    // MARK: - Core Services

    @StateObject private var appSettings: AppSettings
    @StateObject private var windowManager: WindowManager
    @StateObject private var previewManager: PreviewManager
    @StateObject private var hotkeyManager: HotkeyManager

    private let windowStateManager: WindowStateManager
    private let logger = AppLogger.interface

    init() {
        logger.debug("Initializing core application services")

        let settings = AppSettings()
        let window = WindowManager(appSettings: settings)
        let preview = PreviewManager(windowManager: window)
        let hotkey = HotkeyManager(appSettings: settings, windowManager: window)
        let stateManager = WindowStateManager()

        self._appSettings = StateObject(wrappedValue: settings)
        self._windowManager = StateObject(wrappedValue: window)
        self._previewManager = StateObject(wrappedValue: preview)
        self._hotkeyManager = StateObject(wrappedValue: hotkey)
        self.windowStateManager = stateManager

        configureApplicationDelegate(stateManager)
        restoreWindowStates(settings, preview, window)

        logger.info("Application services initialized successfully")
    }

    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
        .commands {
            CommandGroup(before: .newItem) {
                Button("New Preview Window") {
                    createPreviewWindow()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Close All Windows") {
                    closeAllPreviewWindows()
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

    // MARK: - Private Methods

    private func configureApplicationDelegate(_ stateManager: WindowStateManager) {
        if NSApplication.shared.delegate == nil {
            NSApplication.shared.delegate = AppDelegate(windowStateManager: stateManager)
        }
    }

    private func restoreWindowStates(
        _ settings: AppSettings, _ preview: PreviewManager, _ window: WindowManager
    ) {
        DispatchQueue.main.async {
            windowStateManager.restoreWindows { frame in
                createPreviewWindow(at: frame)
            }
        }
    }

    private func createPreviewWindow(at frame: NSRect? = nil) {
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

        configureWindow(window)
        setupWindowContent(window)
        window.makeKeyAndOrderFront(nil)

        logger.info("Created new preview window")
    }

    private func configureWindow(_ window: NSWindow) {
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.level = .statusBar + 1
        window.collectionBehavior = [.fullScreenAuxiliary]
    }

    private func setupWindowContent(_ window: NSWindow) {
        let contentView = ContentView(
            appSettings: appSettings,
            previewManager: previewManager,
            windowManager: windowManager
        )
        window.contentView = NSHostingView(rootView: contentView)
    }

    private func closeAllPreviewWindows() {
        windowStateManager.saveWindowStates()
        NSApplication.shared.windows.forEach { window in
            if window.contentView?.ancestorOrSelf(ofType: NSHostingView<ContentView>.self) != nil {
                window.close()
            }
        }
        logger.info("Closed all preview windows")
    }
}

// MARK: - Window State Manager

class WindowStateManager {
    private let logger = AppLogger.interface
    private let windowPositionsKey = "StoredWindowPositions"

    struct WindowState: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    func saveWindowStates() {
        var positions: [WindowState] = []

        NSApplication.shared.windows.forEach { window in
            if window.contentView?.ancestorOrSelf(ofType: NSHostingView<ContentView>.self) != nil {
                positions.append(
                    WindowState(
                        x: window.frame.origin.x,
                        y: window.frame.origin.y,
                        width: window.frame.width,
                        height: window.frame.height
                    ))
            }
        }

        do {
            let data = try JSONEncoder().encode(positions)
            UserDefaults.standard.set(data, forKey: windowPositionsKey)
            logger.info("Saved \(positions.count) window positions")
        } catch {
            logger.logError(error, context: "Failed to save window positions")
        }
    }

    func restoreWindows(using createWindow: (NSRect) -> Void) {
        guard let data = UserDefaults.standard.data(forKey: windowPositionsKey) else { return }

        do {
            let positions = try JSONDecoder().decode([WindowState].self, from: data)
            positions.forEach { position in
                createWindow(
                    NSRect(
                        x: position.x,
                        y: position.y,
                        width: position.width,
                        height: position.height
                    ))
            }
            logger.info("Restored \(positions.count) windows")
        } catch {
            logger.logError(error, context: "Failed to restore window positions")
        }
    }
}
