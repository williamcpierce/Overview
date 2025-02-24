/*
 Onboarding/OnboardingCoordinator.swift
 Overview

 Created by William Pierce on 2/10/25.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class OnboardingCoordinator: ObservableObject {
    // Permission state tracking
    enum PermissionStatus: Equatable {
        case unknown
        case denied
        case granted
    }

    struct PermissionStatuses {
        let screenRecording: Bool
    }

    // Dependencies
    private let logger = AppLogger.interface

    // Actions
    var onPermissionStatusChanged: ((Bool) -> Void)?

    // Private State
    private var onboardingWindow: NSWindow?
    private var continuationHandler: CheckedContinuation<Void, Never>?
    private var permissionCheckTimer: Timer?

    // Published State
    @Published var screenRecordingPermission: PermissionStatus = .denied

    func startOnboarding() async {
        NSApp.setActivationPolicy(.regular)

        await withCheckedContinuation { continuation in
            continuationHandler = continuation
            createOnboardingWindow()
        }

        stopPermissionMonitoring()
        NSApp.setActivationPolicy(.accessory)
    }

    private func createOnboardingWindow() {
        guard onboardingWindow == nil else { return }

        let onboardingView = OnboardingView(coordinator: self).cornerRadius(8)
        let hostingView = NSHostingView(rootView: onboardingView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 320),
            styleMask: [.fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.contentView = hostingView
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false

        self.onboardingWindow = window

        DispatchQueue.main.async { [weak self] in
            self?.onboardingWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        logger.debug("Onboarding window created")
    }

    func requestScreenRecordingPermission() {
        logger.debug("Requesting screen recording permission")
        startPermissionMonitoring()

        Task {
            do {
                _ = try await SCShareableContent.current
                screenRecordingPermission = .granted
                stopPermissionMonitoring()
                logger.info("Screen recording permission granted after request")
            } catch {
                screenRecordingPermission = .denied
                logger.info(
                    "Screen recording permission denied after request: \(error.localizedDescription)"
                )
            }
        }
    }

    func openScreenRecordingPreferences() {
        logger.debug("Opening screen recording preferences")
        guard
            let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        else {
            logger.error("Failed to create screen recording preferences URL")
            return
        }
        NSWorkspace.shared.open(url)
    }

    func completeOnboarding() {
        logger.info("Completing onboarding flow")
        stopPermissionMonitoring()

        onboardingWindow?.close()
        onboardingWindow = nil

        continuationHandler?.resume(returning: ())
        continuationHandler = nil
    }

    func restartApp() {
        logger.debug("Initiating application restart")

        let process = Process()
        process.executableURL = Bundle.main.executableURL
        process.arguments = []

        do {
            try process.run()
            NSApplication.shared.terminate(nil)
        } catch {
            logger.logError(error, context: "Failed to restart application")
        }
    }

    // MARK: - Permission Monitoring

    private func startPermissionMonitoring() {
        guard permissionCheckTimer == nil else { return }

        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkPermissions()
            }
        }
    }

    private func stopPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    private func checkPermissions() async {
        do {
            _ = try await SCShareableContent.current
            screenRecordingPermission = .granted
            logger.info("Screen recording permission granted")
        } catch {
            screenRecordingPermission = .denied
            logger.info("Screen recording permission still denied: \(error.localizedDescription)")
        }

        // Notify permission manager of changes
        onPermissionStatusChanged?(
            screenRecordingPermission == .granted
        )

        if screenRecordingPermission == .granted {
            stopPermissionMonitoring()
        }
    }
}
