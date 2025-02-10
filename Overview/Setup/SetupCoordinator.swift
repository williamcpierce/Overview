/*
 Setup/SetupCoordinator.swift
 Overview

 Created by William Pierce on 2/10/25.
*/

import SwiftUI

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

    // Published State
    @Published var shouldShowSetup: Bool
    @Published private(set) var hasScreenRecordingPermission: Bool = false
    @Published private(set) var hasRequestedPermission: Bool = false
    @Published private(set) var hasCreatedWindow: Bool = false
    @Published private(set) var isEditModeEnabled: Bool = false

    // Singleton
    static let shared = SetupCoordinator()

    private init() {
        self.shouldShowSetup = !UserDefaults.standard.bool(
            forKey: SetupKeys.hasCompletedSetup)
        logger.debug("Initializing onboarding coordinator: shouldShow=\(shouldShowSetup)")
    }

    func setDependencies(windowManager: WindowManager, previewManager: PreviewManager) {
        self.windowManager = windowManager
        self.previewManager = previewManager
    }

    func startSetupIfNeeded() async {
        guard shouldShowSetup else { return }

        // Set activation policy to regular during onboarding
        NSApp.setActivationPolicy(.regular)

        await withCheckedContinuation { continuation in
            continuationHandler = continuation
            setupSetupWindow()
        }

        // Reset to accessory after onboarding
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupSetupWindow() {
        guard onboardingWindow == nil else { return }

        let onboardingView = SetupView(coordinator: self)
        let hostingView = NSHostingView(rootView: onboardingView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true

        self.onboardingWindow = window

        DispatchQueue.main.async { [weak self] in
            self?.onboardingWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        logger.debug("Setup window created")
    }

    func moveWindow(by translation: CGSize) {
        guard let window: NSWindow = onboardingWindow else { return }
        let currentFrame: NSRect = window.frame
        window.setFrame(
            NSRect(
                x: currentFrame.origin.x + translation.width,
                y: currentFrame.origin.y - translation.height,
                width: currentFrame.width,
                height: currentFrame.height
            ),
            display: true
        )
    }

    func requestScreenRecordingPermission() async {
        hasRequestedPermission = true
        await checkScreenRecordingPermission()
    }

    func checkScreenRecordingPermission() async {
        do {
            try await captureServices.requestScreenRecordingPermission()
            hasScreenRecordingPermission = true
            logger.info("Screen recording permission granted")
        } catch {
            hasScreenRecordingPermission = false
            logger.logError(error, context: "Screen recording permission check failed")
        }
    }

    func createInitialWindow() async {
        guard let windowManager = windowManager else {
            logger.error("Window manager not available")
            return
        }

        do {
            try await windowManager.createPreviewWindow()
            hasCreatedWindow = true
            logger.info("Initial preview window created")
        } catch {
            logger.logError(error, context: "Failed to create initial window")
        }
    }

    func toggleEditMode() {
        guard let previewManager = previewManager else {
            logger.error("Preview manager not available")
            return
        }

        previewManager.editModeEnabled.toggle()
        isEditModeEnabled = previewManager.editModeEnabled
    }

    func openSystemPreferences() {
        logger.debug("Opening system preferences for screen recording")
        guard
            let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        else {
            logger.error("Failed to create system preferences URL")
            return
        }
        NSWorkspace.shared.open(url)
    }

    func completeSetup() {
        logger.info("Completing onboarding flow")
        UserDefaults.standard.set(true, forKey: SetupKeys.hasCompletedSetup)
        shouldShowSetup = false

        onboardingWindow?.close()
        onboardingWindow = nil

        continuationHandler?.resume(returning: ())
        continuationHandler = nil
    }

    func resetSetup() {
        logger.info("Resetting onboarding state")
        UserDefaults.standard.set(false, forKey: SetupKeys.hasCompletedSetup)
        shouldShowSetup = true
        Task {
            await startSetupIfNeeded()
        }
    }
}
