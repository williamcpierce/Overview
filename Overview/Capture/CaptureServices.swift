/* Capture/CaptureServices.swift — Shared source discovery adapter. */
import ScreenCaptureKit

@MainActor
final class CaptureServices {
    static let shared = CaptureServices()
    private let availability = CaptureAvailabilityService()
    func getAvailableSources() async throws -> [SCWindow] { try await availability.getAvailableSources() }
}
