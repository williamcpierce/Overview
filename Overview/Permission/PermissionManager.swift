/*
 Permission/PermissionManager.swift
 Overview

 Created by William Pierce on 2/15/25.

 Manages screen recording and accessibility permission state and coordinates setup when needed.
*/

import CoreGraphics
import ScreenCaptureKit
import SwiftUI

@MainActor
final class PermissionManager: ObservableObject {
    // Dependencies
    private let logger = AppLogger.capture
    private let permissionSetupCoordinator: PermissionSetupCoordinator

    // Private State
    private var isRequestingPermission: Bool = false

    // Published State
    @Published private(set) var screenRecordingStatus: PermissionStatus = .unknown {
        didSet {
            if oldValue != screenRecordingStatus {
                logger.info("Screen recording permission status changed: \(screenRecordingStatus)")
            }
        }
    }

    @Published private(set) var accessibilityStatus: PermissionStatus = .unknown {
        didSet {
            if oldValue != accessibilityStatus {
                logger.info("Accessibility permission status changed: \(accessibilityStatus)")
            }
        }
    }

    // Computed properties for backward compatibility and convenience
    var permissionStatus: PermissionStatus {
        screenRecordingStatus
    }

    var hasRequiredPermissions: Bool {
        screenRecordingStatus == .granted && accessibilityStatus == .granted
    }

    var hasScreenRecordingPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    init() {
        self.permissionSetupCoordinator = PermissionSetupCoordinator()
        self.permissionSetupCoordinator.onPermissionStatusChanged = { [weak self] permissions in
            self?.screenRecordingStatus = permissions.screenRecording ? .granted : .denied
            self?.accessibilityStatus = permissions.accessibility ? .granted : .denied
        }
        logger.debug("Initializing permission manager")
    }

    // MARK: - Permission Types

    enum PermissionStatus: Equatable {
        case unknown
        case denied
        case granted
    }

    // MARK: - Public Methods

    func ensurePermissions() async throws {
        if screenRecordingStatus == .granted && accessibilityStatus == .granted {
            return
        }

        guard !isRequestingPermission else {
            logger.debug("Permission check already in progress")
            return
        }

        isRequestingPermission = true
        defer { isRequestingPermission = false }

        let hasScreenAccess: Bool = CGPreflightScreenCaptureAccess()
        let hasAccessibilityAccess: Bool = AXIsProcessTrusted()

        if hasScreenAccess && hasAccessibilityAccess {
            screenRecordingStatus = .granted
            accessibilityStatus = .granted
        } else {
            try await launchSetupFlow()
            updatePermissionStatus()

            if screenRecordingStatus != .granted || accessibilityStatus != .granted {
                throw PermissionError.permissionDenied
            }
        }
    }

    func updatePermissionStatus() {
        Task {
            do {
                _ = try await SCShareableContent.current
                screenRecordingStatus = .granted
                logger.info("Screen recording permission granted")
            } catch {
                screenRecordingStatus = .denied
                logger.info(
                    "Screen recording permission still denied: \(error.localizedDescription)")
            }

            let hasAccessibilityAccess = AXIsProcessTrusted()
            accessibilityStatus = hasAccessibilityAccess ? .granted : .denied
            logger.info(
                "Accessibility permission status: \(hasAccessibilityAccess ? "granted" : "denied")")
        }
    }

    // MARK: - Private Methods

    private func launchSetupFlow() async throws {
        logger.info("Launching setup flow")
        await permissionSetupCoordinator.startSetup()

        try? await Task.sleep(nanoseconds: 500_000_000)
        updatePermissionStatus()
    }
}

// MARK: - Permission Error

enum PermissionError: LocalizedError {
    case permissionDenied
    case setupIncomplete

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Required permissions were denied"
        case .setupIncomplete:
            return "Setup process was not completed"
        }
    }
}
