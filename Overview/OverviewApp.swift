import SwiftUI
import Cocoa

@MainActor
class OverviewAppDelegate: NSObject, NSApplicationDelegate {
    var windowService: WindowService!
    let appSettings = AppSettings()
    let sourceManager: SourceManager
    let previewManager: PreviewManager
    let hotkeyManager: HotkeyManager
    
    private var observers: [NSObjectProtocol] = []
    private let logger = AppLogger.interface
    
    override init() {
        // Initialize managers in the correct order
        sourceManager = SourceManager(appSettings: appSettings)
        previewManager = PreviewManager(sourceManager: sourceManager)
        hotkeyManager = HotkeyManager(appSettings: appSettings, sourceManager: sourceManager)
        
        super.init()
        
        // Create window service after super.init()
        windowService = WindowService(
            settings: appSettings,
            preview: previewManager,
            source: sourceManager
        )
        
        setupTerminationHandler()
    }
    
    private func setupTerminationHandler() {
        let observer = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleTermination()
        }
        observers.append(observer)
    }
    
    private func handleTermination() {
        windowService.saveWindowStates()
        logger.info("Application terminating, window states saved")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Restore window states after launch
        DispatchQueue.main.async { [weak self] in
            self?.windowService.restoreWindowStates()
        }
    }
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}

@main
struct OverviewApp: App {
    @NSApplicationDelegateAdaptor(OverviewAppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
        .commands {
            CommandGroup(before: .newItem) {
                Button("New Preview Window") {
                    appDelegate.windowService.createPreviewWindow()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandMenu("Edit") {
                Toggle("Edit Mode", isOn: editModeBinding)
            }
        }
        
        Settings {
            SettingsView(
                appSettings: appDelegate.appSettings,
                sourceManager: appDelegate.sourceManager
            )
        }
    }
    
    private var editModeBinding: Binding<Bool> {
        Binding(
            get: { appDelegate.previewManager.editModeEnabled },
            set: { appDelegate.previewManager.editModeEnabled = $0 }
        )
    }
}
