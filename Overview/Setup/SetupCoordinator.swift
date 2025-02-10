/*
 Setup/SetupCoordinator.swift
 Overview
*/

import SwiftUI

@MainActor
final class SetupCoordinator: ObservableObject {
    private enum SetupKeys {
        static let hasCompletedSetup: String = "hasCompletedSetup"
    }

    // Dependencies
    private let captureServices = CaptureServices.shared
    private let logger = AppLogger.interface
    private weak var windowManager: WindowManager?
    private weak var previewManager: PreviewManager?

    // State
    private var onboardingWindow: NSWindow?
    private var continuationHandler: CheckedContinuation<Void, Never>?

    @Published var shouldShowSetup: Bool
    @Published private(set) var hasScreenRecordingPermission: Bool = false
    @Published private(set) var hasRequestedPermission: Bool = false
    @Published private(set) var hasCreatedWindow: Bool = false
    @Published private(set) var isEditModeEnabled: Bool = false

    static let shared = SetupCoordinator()

    private init() {
        self.shouldShowSetup = !UserDefaults.standard.bool(forKey: SetupKeys.hasCompletedSetup)
        logger.debug("Initializing onboarding coordinator: shouldShow=\(shouldShowSetup)")
    }

    func setDependencies(windowManager: WindowManager, previewManager: PreviewManager) {
        self.windowManager = windowManager
        self.previewManager = previewManager
    }

    func startSetupIfNeeded() async {
        guard shouldShowSetup else { return }
        NSApp.setActivationPolicy(.regular)

        await withCheckedContinuation { continuation in
            continuationHandler = continuation
            setupSetupWindow()
        }

        NSApp.setActivationPolicy(.accessory)
    }

    private func setupSetupWindow() {
        guard onboardingWindow == nil else { return }

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
        window.contentView = NSHostingView(rootView: SetupView(coordinator: self))
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
        UserDefaults.standard.set(true, forKey: SetupKeys.hasCompletedSetup)
        shouldShowSetup = false

        onboardingWindow?.close()
        onboardingWindow = nil

        continuationHandler?.resume(returning: ())
        continuationHandler = nil

        logger.info("Onboarding completed")
    }

    func resetSetup() {
        UserDefaults.standard.set(false, forKey: SetupKeys.hasCompletedSetup)
        shouldShowSetup = true
        Task {
            await startSetupIfNeeded()
        }
        logger.info("Onboarding reset")
    }
}
