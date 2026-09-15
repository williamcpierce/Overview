/* Source/SourceManager.swift — One inventory and focus service shared by all previews. */
import Combine
@preconcurrency import ScreenCaptureKit
import SwiftUI

@MainActor
final class SourceManager: ObservableObject {
    struct SourceID: Hashable { let processID: pid_t; let windowID: CGWindowID }
    @Published private(set) var focusedBundleId: String?
    @Published private(set) var focusedProcessId: pid_t?
    @Published private(set) var focusedWindowID: CGWindowID?
    @Published private(set) var isOverviewActive = true
    @Published private(set) var sourceTitles: [SourceID: String] = [:]
    @Published private(set) var sources: [SCWindow] = []
    @Published private(set) var inventoryError: String?
    @Published private(set) var isSleeping = false
    @Published private(set) var accessibilityEnabled = false
    @Published private(set) var focusMessage: String?
    let permissionManager: PermissionManager
    private let focus = SourceFocusService()
    private let filter = SourceFilterService()
    private var subscriptions = Set<AnyCancellable>()
    private var timer: Task<Void, Never>?
    private var refreshTask: Task<[SCWindow], Error>?
    private var lastRefresh = Date.distantPast
    private var observers = 0

    init(permissionManager: PermissionManager) {
        self.permissionManager = permissionManager
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            center.publisher(for: name).sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.permissionManager.updatePermissionStatus()
                    self.updateFocus()
                    if self.observers > 0 { _ = try? await self.refresh() }
                }
            }.store(in: &subscriptions)
        }
        center.publisher(for: NSWorkspace.willSleepNotification).sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.isSleeping = true }
        }.store(in: &subscriptions)
        center.publisher(for: NSWorkspace.didWakeNotification).sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isSleeping = false
                self?.permissionManager.updatePermissionStatus()
                _ = try? await self?.refresh()
            }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification).sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.permissionManager.updatePermissionStatus()
                self?.updateFocus()
            }
        }.store(in: &subscriptions)
        updateFocus()
    }

    func beginTracking() {
        observers += 1
        guard timer == nil else { return }
        timer = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                if let self, !self.isSleeping {
                    _ = try? await self.refresh()
                    self.updateFocus()
                }
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { break }
            }
        }
    }
    func endTracking() {
        observers = max(0, observers - 1)
        if observers == 0 { timer?.cancel(); timer = nil }
    }

    func getAvailableSources() async throws -> [SCWindow] {
        try await permissionManager.ensurePermission()
        return try await refresh()
    }
    func getFilteredSources() async throws -> [SCWindow] { filtered(try await getAvailableSources()) }
    func filtered(_ sources: [SCWindow]) -> [SCWindow] {
        filter.filterSources(sources)
    }

    @discardableResult
    func refresh() async throws -> [SCWindow] {
        guard permissionManager.permissionStatus == .granted else { return sources }
        if let refreshTask { return try await refreshTask.value }
        guard Date().timeIntervalSince(lastRefresh) >= 1 else { return sources }
        lastRefresh = Date()
        let task = Task { try await CaptureServices.shared.getAvailableSources() }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let fresh = try await task.value
            sources = fresh
            sourceTitles = Dictionary(fresh.compactMap { source in
                guard let pid = source.owningApplication?.processID, let title = source.title else { return nil }
                return (SourceID(processID: pid, windowID: source.windowID), title)
            }, uniquingKeysWith: { first, _ in first })
            inventoryError = nil
            return fresh
        } catch {
            permissionManager.updatePermissionStatus()
            inventoryError = "Unable to refresh source windows"
            throw error
        }
    }

    func resolve(_ identity: SourceIdentity) -> (SourceResolution, SCWindow?) {
        let candidates = sources.filter { $0.identity != nil }
        let result = SourceResolver.resolve(identity, among: candidates.compactMap(\.identity))
        if case .unique(let index) = result { return (result, candidates[index]) }
        return (result, nil)
    }

    @discardableResult
    func focusSource(_ source: SCWindow) -> Bool {
        let result = focus.focusSource(source: source)
        switch result {
        case .exactWindow: focusMessage = nil
        case .application: focusMessage = "Application activated; exact window focus unavailable"
        case .unavailable: focusMessage = "Client is unavailable"
        }
        updateFocus()
        return result != .unavailable
    }

    func focusSource(withTitle title: String) -> Bool {
        // Legacy shortcuts contain titles only. Refuse cross-client ambiguity.
        let candidates = sources.filter { $0.title == title }
        guard candidates.count == 1, let identity = candidates[0].identity,
              let resolved = resolve(identity).1 else { return false }
        return focusSource(resolved)
    }

    func requestAccessibility() { focus.requestAccessibility(); updateFocus() }
    func updateFocus() {
        let app = NSWorkspace.shared.frontmostApplication
        focusedProcessId = app?.processIdentifier
        focusedBundleId = app?.bundleIdentifier
        isOverviewActive = app?.bundleIdentifier == Bundle.main.bundleIdentifier
        accessibilityEnabled = focus.accessibilityEnabled
        focusedWindowID = nil
        if let pid = focusedProcessId, let title = focus.focusedTitle(pid: pid) {
            let matches = sources.filter { $0.owningApplication?.processID == pid && $0.title == title }
            if matches.count == 1 { focusedWindowID = matches[0].windowID }
        }
    }
}

extension SCWindow {
    var identity: SourceIdentity? {
        guard let bundle = owningApplication?.bundleIdentifier, let title, !title.isEmpty else { return nil }
        return SourceIdentity(bundleIdentifier: bundle, windowTitle: title)
    }
}
