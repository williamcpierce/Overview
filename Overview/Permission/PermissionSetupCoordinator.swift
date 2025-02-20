/*
 Permission/PermissionSetupCoordinator.swift
 Overview

 Created by William Pierce on 2/10/25.
*/

import ScreenCaptureKit
import SwiftUI

@MainActor
final class PermissionSetupCoordinator: ObservableObject {
    // Permission state tracking
    enum PermissionStatus: Equatable {
        case unknown
        case denied
        case granted
    }

    struct PermissionStatuses {
        let screenRecording: Bool
        let accessibility: Bool
    }

    // Dependencies
    private let logger = AppLogger.interface

    // Actions
    var onPermissionStatusChanged: ((PermissionStatuses) -> Void)?

    // Private State
    private var setupWindow: NSWindow?
    private var continuationHandler: CheckedContinuation<Void, Never>?
    private var permissionCheckTimer: Timer?

    // Published State
    @Published var screenRecordingPermission: PermissionStatus = .denied
    @Published var accessibilityPermission: PermissionStatus = .denied

    func startSetup() async {
        NSApp.setActivationPolicy(.regular)

        await withCheckedContinuation { continuation in
            continuationHandler = continuation
            createSetupWindow()
        }

        stopPermissionMonitoring()
        NSApp.setActivationPolicy(.accessory)
    }

    private func createSetupWindow() {
        guard setupWindow == nil else { return }

        let permissionSetupView = PermissionSetupView(coordinator: self)
        let hostingView = NSHostingView(rootView: permissionSetupView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.title = "Overview Permission Setup"
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.contentView = hostingView
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false

        self.setupWindow = window

        DispatchQueue.main.async { [weak self] in
            self?.setupWindow?.makeKeyAndOrderFront(nil)
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

    func requestAccessibilityPermission() {
        logger.debug("Requesting accessibility permission")
        startPermissionMonitoring()

        let trusted: Bool = AXIsProcessTrusted()
        if trusted {
            accessibilityPermission = .granted
            logger.info("Accessibility permission already granted")
        } else {
            logger.info("Accessibility permission not yet granted")
            accessibilityPermission = .denied
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

    func openAccessibilityPreferences() {
        logger.debug("Opening accessibility preferences")
        guard
            let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            logger.error("Failed to create accessibility preferences URL")
            return
        }
        NSWorkspace.shared.open(url)
    }

    func completeSetup() {
        logger.info("Completing setup flow")
        stopPermissionMonitoring()

        setupWindow?.close()
        setupWindow = nil

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
                await self?.checkPermissions()
            }
        }
    }

    private func stopPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    private func checkPermissions() async {
        // Check screen recording permission
        do {
            _ = try await SCShareableContent.current
            screenRecordingPermission = .granted
            logger.info("Screen recording permission granted")
        } catch {
            screenRecordingPermission = .denied
            logger.info("Screen recording permission still denied: \(error.localizedDescription)")
        }

        // Check accessibility permission
        let trusted: Bool = AXIsProcessTrusted()
        accessibilityPermission = trusted ? .granted : .denied
        logger.info("Accessibility permission status: \(trusted ? "granted" : "denied")")

        // Notify permission manager of changes
        onPermissionStatusChanged?(
            PermissionStatuses(
                screenRecording: screenRecordingPermission == .granted,
                accessibility: accessibilityPermission == .granted
            )
        )

        // Stop monitoring if both permissions are granted
        if screenRecordingPermission == .granted && accessibilityPermission == .granted {
            stopPermissionMonitoring()
        }
    }
}
