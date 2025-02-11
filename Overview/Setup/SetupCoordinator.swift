/*
 Setup/SetupCoordinator.swift
 Overview

 Created by William Pierce on 2/10/25.
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

    // Private State
    private var onboardingWindow: NSWindow?
    private var continuationHandler: CheckedContinuation<Void, Never>?

    // Published State
    @Published var shouldShowSetup: Bool
    @Published private(set) var hasScreenRecordingPermission: Bool = false
    @Published private(set) var hasRequestedPermission: Bool = false

    static let shared = SetupCoordinator()

    private init() {
        #if DEBUG
            // Always show setup during development
            self.shouldShowSetup = true
            logger.debug("Debug mode: Setup will always show")
        #else
            self.shouldShowSetup = !UserDefaults.standard.bool(forKey: SetupKeys.hasCompletedSetup)
            logger.debug("Initializing setup coordinator: shouldShow=\(shouldShowSetup)")
        #endif
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

    func requestScreenRecordingPermission() async {
        hasRequestedPermission = true
        await checkScreenRecordingPermission()
    }

    func checkScreenRecordingPermission() async {
        do {
            try await captureServices.requestScreenRecordingPermission(duringSetup: true)
            hasScreenRecordingPermission = true
            logger.info("Screen recording permission granted")
        } catch {
            hasScreenRecordingPermission = false
            logger.logError(error, context: "Screen recording permission check failed")
        }
    }

    func openSystemPreferences() {
        logger.debug("Opening system preferences for screen recording")
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
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
