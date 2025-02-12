/*
 Setup/SetupCoordinator.swift
 Overview
 
 Created by William Pierce on 2/10/25.
*/

import SwiftUI
import ScreenCaptureKit

@MainActor
final class SetupCoordinator: ObservableObject {
    // Constants
    private enum SetupKeys {
        static let hasCompletedSetup: String = "hasCompletedSetup"
    }
    
    // Dependencies
    private let captureServices = CaptureServices.shared
    private let logger = AppLogger.interface
    private weak var windowManager: WindowManager?
    private weak var previewManager: PreviewManager?
    
    // Private State
    private var onboardingWindow: NSWindow?
    private var continuationHandler: CheckedContinuation<Void, Never>?
    private var permissionCheckTimer: Timer?
    
    // Published State
    @Published var shouldShowSetup: Bool
    @Published var screenRecordingPermission: PermissionStatus = .unknown
    @Published var accessibilityPermission: PermissionStatus = .unknown
    
    // Singleton
    static let shared = SetupCoordinator()
    
    private init() {
        self.shouldShowSetup = !UserDefaults.standard.bool(forKey: SetupKeys.hasCompletedSetup)
        logger.debug("Initializing setup coordinator: shouldShow=\(shouldShowSetup)")
    }

    func setDependencies(windowManager: WindowManager, previewManager: PreviewManager) {
        self.windowManager = windowManager
        self.previewManager = previewManager
    }
    
    func startSetupIfNeeded() async {
        guard shouldShowSetup else { return }
        
        // Set activation policy to regular during setup
        NSApp.setActivationPolicy(.regular)
        
        // Start permission monitoring
        startPermissionMonitoring()
        
        await withCheckedContinuation { continuation in
            continuationHandler = continuation
            setupWindow()
        }
        
        // Cleanup
        stopPermissionMonitoring()
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func startPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkPermissions()
            }
        }
    }
    
    private func stopPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
    
    private func setupWindow() {
        guard onboardingWindow == nil else { return }
        
        let setupView = SetupView(coordinator: self)
        let hostingView = NSHostingView(rootView: setupView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Welcome to Overview"
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        
        self.onboardingWindow = window
        
        DispatchQueue.main.async { [weak self] in
            self?.onboardingWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        logger.debug("Setup window created")
    }
    
    func checkPermissions() async {
        // Check Screen Recording using direct SCShareableContent check
        do {
            _ = try await SCShareableContent.current
            screenRecordingPermission = .granted
            logger.info("Screen recording permission granted")
        } catch {
            screenRecordingPermission = .denied
            logger.info("Screen recording permission denied: \(error.localizedDescription)")
        }
        
        // Check Accessibility (existing code remains the same)
        let accessibilityEnabled = AXIsProcessTrusted()
        accessibilityPermission = accessibilityEnabled ? .granted : .denied
        logger.info("Accessibility permission state: \(accessibilityEnabled ? "granted" : "denied")")
    }

    func requestScreenRecordingPermission() {
        logger.debug("Requesting screen recording permission")
        
        // Request access
        Task {
            do {
                _ = try await SCShareableContent.current
                screenRecordingPermission = .granted
                logger.info("Screen recording permission granted after request")
            } catch {
                screenRecordingPermission = .denied
                logger.info("Screen recording permission denied after request: \(error.localizedDescription)")
            }
        }
    }
    
    func openAccessibilityPreferences() {
        logger.debug("Opening accessibility preferences")
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            logger.error("Failed to create accessibility preferences URL")
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    func openScreenRecordingPreferences() {
        logger.debug("Opening screen recording preferences")
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            logger.error("Failed to create screen recording preferences URL")
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    func completeSetup() {
        logger.info("Completing setup flow")
        UserDefaults.standard.set(true, forKey: SetupKeys.hasCompletedSetup)
        shouldShowSetup = false
        
        onboardingWindow?.close()
        onboardingWindow = nil
        
        continuationHandler?.resume(returning: ())
        continuationHandler = nil
    }
}

// Permission state tracking
enum PermissionStatus: Equatable {
    case unknown
    case denied
    case granted
}
