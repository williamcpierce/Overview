/* Permission/PermissionManager.swift — Awaited, shared Screen Recording authorization. */
import CoreGraphics
import SwiftUI

@MainActor
final class PermissionManager: ObservableObject {
    enum PermissionStatus: Equatable { case unknown, denied, granted }
    @Published private(set) var permissionStatus: PermissionStatus = .unknown
    private let onboarding = OnboardingCoordinator()
    private lazy var gate = PermissionGate(check: { CGPreflightScreenCaptureAccess() }, request: { [weak self] in
        await self?.onboarding.startOnboarding()
    })

    func ensurePermission() async throws {
        let allowed = await gate.ensure()
        setStatus(allowed)
        guard allowed else { throw PermissionError.permissionDenied }
    }

    private func setStatus(_ allowed: Bool) {
        let next: PermissionStatus = allowed ? .granted : .denied
        if permissionStatus != next { permissionStatus = next }
    }

    func updatePermissionStatus() {
        setStatus(CGPreflightScreenCaptureAccess())
    }
}

enum PermissionError: LocalizedError {
    case permissionDenied, setupIncomplete
    var errorDescription: String? { "Screen Recording permission is required. Enable Overview Dev in System Settings." }
}
