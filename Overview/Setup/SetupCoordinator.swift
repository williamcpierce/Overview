/*
 Setup/SetupCoordinator.swift
 Overview

 Created by William Pierce on 2/10/25.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class SetupCoordinator: ObservableObject {
    // Permission state tracking
    enum PermissionStatus: Equatable {
        case unknown
        case denied
        case granted
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

    func startSetup() async {
        NSApp.setActivationPolicy(.regular)

        await withCheckedContinuation { continuation in
            continuationHandler = continuation
            setupWindow()
        }

        stopPermissionMonitoring()
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupWindow() {
        guard onboardingWindow == nil else { return }

        let setupView = SetupView(coordinator: self)
        let hostingView = NSHostingView(rootView: setupView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 460),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.title = "Welcome to Overview"
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

        logger.debug("Setup window created")
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

    func completeSetup() {
        logger.info("Completing setup flow")
        stopPermissionMonitoring()

        onboardingWindow?.close()
        onboardingWindow = nil

        // Always resume continuation when completing setup
        continuationHandler?.resume(returning: ())
        continuationHandler = nil
    }

    // MARK: - Permission Monitoring

    private func startPermissionMonitoring() {
        guard permissionCheckTimer == nil else { return }

        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkScreenRecordingPermission()
            }
        }
    }

    private func stopPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    private func checkScreenRecordingPermission() async {
        do {
            _ = try await SCShareableContent.current
            screenRecordingPermission = .granted
            stopPermissionMonitoring()
            onPermissionStatusChanged?(true)  // Notify permission manager
            logger.info("Screen recording permission granted")
        } catch {
            screenRecordingPermission = .denied
            onPermissionStatusChanged?(false)  // Notify permission manager
            logger.info("Screen recording permission still denied: \(error.localizedDescription)")
        }
    }

}
