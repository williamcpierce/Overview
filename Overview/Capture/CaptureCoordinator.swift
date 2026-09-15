/* Capture/CaptureCoordinator.swift — Source groups, optimistic focus, and lifecycle integration. */
import Combine
import Defaults
import ScreenCaptureKit
import SwiftUI

@MainActor
final class CaptureCoordinator: ObservableObject {
    @Published private(set) var capturedFrame: CapturedFrame?
    @Published private(set) var state: CaptureState = .idle
    @Published private(set) var isSourceAppFocused = false
    @Published private(set) var isSourceWindowFocused = false
    @Published private(set) var sourceWindowTitle: String?
    @Published private(set) var sourceApplicationTitle: String?
    /// Currently displayed group member.
    @Published private(set) var sourceIdentity: SourceIdentity?
    @Published private(set) var sources: [SourceIdentity] = []
    @Published var hideWhenFocused = false
    /// True when hide-when-focused has no inactive member left to show.
    @Published private(set) var shouldHideForFocus = false
    @Published private(set) var resolutionMessage: String?
    @Published var selectedSource: SCWindow?
    /// Optimistic focus owned by Overview after a preview click; wins over ambiguous OS focus.
    @Published private(set) var localFocusedIdentity: SourceIdentity?

    /// Source groups with 2+ clients always swap; single-source windows use the explicit toggle.
    var effectiveHideWhenFocused: Bool {
        SourceGroupSelection.swapsWhenFocused(sourceCount: sources.count, hideWhenFocused: hideWhenFocused)
    }

    var isCapturing: Bool { state == .running }
    var hasAssignment: Bool { !sources.isEmpty || selectedSource != nil }
    var statusLabel: String { resolutionMessage ?? state.label }
    var applicationFocusOnly: Bool { isSourceAppFocused && !isSourceWindowFocused }
    var focusMessage: String? { sourceManager.focusMessage }
    let id: UUID
    private let sourceManager: SourceManager
    private let permissionManager: PermissionManager
    private let lifecycle: CaptureLifecycle<CaptureEngine>
    private var subscriptions = Set<AnyCancellable>()
    private var pixelSize: CGSize = .zero
    private var resizeTask: Task<Void, Never>?
    private var wantsCapture = false
    private var hidden = false
    private var tracked = false
    private var selectionGeneration = 0

    init(
        sourceManager: SourceManager,
        permissionManager: PermissionManager,
        id: UUID = UUID(),
        sources: [SourceIdentity] = [],
        hideWhenFocused: Bool = false,
        source: SourceIdentity? = nil
    ) {
        self.id = id
        self.sourceManager = sourceManager
        self.permissionManager = permissionManager
        self.hideWhenFocused = hideWhenFocused
        let initialSources: [SourceIdentity]
        if !sources.isEmpty {
            initialSources = sources
        } else if let source {
            initialSources = [source]
        } else {
            initialSources = []
        }
        self.sources = initialSources
        sourceIdentity = initialSources.first
        sourceWindowTitle = initialSources.first?.windowTitle
        wantsCapture = !initialSources.isEmpty
        lifecycle = CaptureLifecycle(session: CaptureEngine(), classify: { error in
            if error is PermissionError { return .permission }
            if let streamError = error as? SCStreamError {
                switch streamError.code {
                case .userDeclined: return .permission
                case .userStopped, .missingEntitlements: return .terminal
                default: return .transient
                }
            }
            return .transient
        })
        lifecycle.$state.sink { [weak self] state in
            self?.state = state
            if state == .permissionRequired { self?.permissionManager.updatePermissionStatus() }
        }.store(in: &subscriptions)
        lifecycle.$frame.assign(to: &$capturedFrame)
        sourceManager.$sources.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.reconcileSource() }
        }.store(in: &subscriptions)
        sourceManager.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.reconcileSource() }
        }.store(in: &subscriptions)
        sourceManager.$isSleeping.sink { [weak self] _ in
            self?.applySuspension()
        }.store(in: &subscriptions)
        permissionManager.$permissionStatus.sink { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self, self.wantsCapture else { return }
                if status == .denied {
                    await self.lifecycle.stop()
                    self.state = .permissionRequired
                } else if status == .granted { self.reconcileSource(force: true) }
            }
        }.store(in: &subscriptions)
    }

    func beginTracking() {
        guard !tracked else { return }
        tracked = true
        sourceManager.beginTracking()
        reconcileSource()
    }

    func close() async {
        selectionGeneration += 1
        wantsCapture = false
        resizeTask?.cancel()
        if tracked { sourceManager.endTracking(); tracked = false }
        await lifecycle.stop()
    }

    func startCapture() async throws {
        guard let source = selectedSource, let identity = source.identity else { return }
        selectionGeneration += 1
        let token = selectionGeneration
        if !sources.contains(where: { $0.matchesClient(identity) }) {
            sources = [identity]
        }
        sourceIdentity = identity
        sourceWindowTitle = source.title
        sourceApplicationTitle = source.owningApplication?.applicationName
        wantsCapture = true
        shouldHideForFocus = false
        resolutionMessage = nil
        do { try await permissionManager.ensurePermission() }
        catch { if token == selectionGeneration { state = .permissionRequired }; throw error }
        guard token == selectionGeneration, wantsCapture else { return }
        lifecycle.start(request(source))
    }

    func stopCapture() async {
        selectionGeneration += 1
        wantsCapture = false
        selectedSource = nil
        sources = []
        sourceIdentity = nil
        localFocusedIdentity = nil
        shouldHideForFocus = false
        resolutionMessage = nil
        await lifecycle.stop()
    }

    func retry() async {
        do {
            try await permissionManager.ensurePermission()
            _ = try await sourceManager.refresh()
            wantsCapture = !sources.isEmpty || selectedSource != nil
            if !sources.isEmpty { reconcileSource(force: true) }
            else if selectedSource != nil { try await startCapture() }
        } catch { state = .permissionRequired }
    }

    func setHidden(_ hidden: Bool) {
        self.hidden = hidden
        applySuspension()
    }

    func setPixelSize(_ size: CGSize) {
        guard abs(size.width - pixelSize.width) > 1 || abs(size.height - pixelSize.height) > 1 else { return }
        pixelSize = size
        resizeTask?.cancel()
        resizeTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 200_000_000) } catch { return }
            await self?.updateStreamConfiguration()
        }
    }

    func updateStreamConfiguration() async {
        guard let selectedSource else { return }
        await lifecycle.update(request(selectedSource))
    }

    /// Click-to-focus: mark the shown member active locally, then activate the OS window.
    func focusSource() {
        guard let identity = sourceIdentity else { return }
        localFocusedIdentity = identity
        reconcileSource(force: true)
        if let source = sourceManager.resolve(identity).1 {
            sourceManager.focusSource(source)
        }
    }

    func setLabel(_ label: String) {
        let trimmed = label.isEmpty ? nil : label
        guard let current = sourceIdentity else { return }
        if let index = sources.firstIndex(where: { $0.matchesClient(current) }) {
            sources[index].label = trimmed
            sourceIdentity = sources[index]
        }
    }

    func setSources(_ newSources: [SourceIdentity]) {
        // Preserve order and drop duplicates by client match.
        var unique: [SourceIdentity] = []
        for source in newSources where !unique.contains(where: { $0.matchesClient(source) }) {
            unique.append(source)
        }
        sources = unique
        // Two or more clients imply swap behavior — persist that so layouts restore correctly.
        if unique.count > 1 { hideWhenFocused = true }
        wantsCapture = !unique.isEmpty
        if unique.isEmpty {
            sourceIdentity = nil
            selectedSource = nil
            shouldHideForFocus = false
            Task { await lifecycle.stop() }
        } else {
            reconcileSource(force: true)
        }
    }

    func setHideWhenFocused(_ value: Bool) {
        hideWhenFocused = value
        reconcileSource(force: true)
    }

    private func request(_ source: SCWindow) -> CaptureRequest {
        CaptureRequest(source: source, frameRate: Defaults[.captureFrameRate], pixelSize: pixelSize)
    }

    private func effectiveFocusedIdentity() -> SourceIdentity? {
        if let localFocusedIdentity { return localFocusedIdentity }
        guard let windowID = sourceManager.focusedWindowID,
              let match = sourceManager.sources.first(where: { $0.windowID == windowID }),
              let identity = match.identity else { return nil }
        return identity
    }

    private func reconcileSource(force: Bool = false) {
        guard wantsCapture, !sources.isEmpty else { return }
        synchronizeFocus()

        let focused = effectiveFocusedIdentity()
        // Clear stale optimistic focus once OS focus has moved elsewhere in the group.
        if let local = localFocusedIdentity, let focused, !local.matchesClient(focused),
           sources.contains(where: { $0.matchesClient(focused) }) {
            localFocusedIdentity = focused
        }

        let candidate = SourceGroupSelection.displayCandidate(
            sources: sources,
            focused: effectiveFocusedIdentity(),
            hideWhenFocused: hideWhenFocused
        )

        if effectiveHideWhenFocused, candidate == nil {
            shouldHideForFocus = true
            resolutionMessage = nil
            selectedSource = nil
            sourceIdentity = sources.first
            applySuspension()
            Task { await lifecycle.stop() }
            return
        }

        shouldHideForFocus = false
        applySuspension()

        guard let candidate else { return }
        guard permissionManager.permissionStatus == .granted else { return }

        let (resolution, source) = sourceManager.resolve(candidate)
        if let source {
            let changed =
                selectedSource?.windowID != source.windowID
                || selectedSource?.owningApplication?.processID != source.owningApplication?.processID
                || !(sourceIdentity?.matchesClient(candidate) ?? false)
            selectedSource = source
            sourceIdentity = candidate
            sourceWindowTitle = source.title
            sourceApplicationTitle = source.owningApplication?.applicationName
            resolutionMessage = nil
            if changed || force || state == .idle || state == .paused {
                lifecycle.start(request(source))
            }
        } else {
            let message =
                resolution == .ambiguous
                ? "Multiple matching clients. Choose a source."
                : "Waiting for \(candidate.label ?? candidate.windowTitle)"
            guard resolutionMessage != message else { return }
            resolutionMessage = message
            selectedSource = nil
            sourceIdentity = candidate
            Task { await lifecycle.stop() }
        }
        synchronizeFocus()
    }

    private func synchronizeFocus() {
        let focusedIdentity = effectiveFocusedIdentity()
        isSourceWindowFocused =
            selectedSource != nil
            && (selectedSource?.windowID == sourceManager.focusedWindowID
                || (focusedIdentity != nil && sourceIdentity?.matchesClient(focusedIdentity!) == true))
        isSourceAppFocused =
            selectedSource?.owningApplication?.processID == sourceManager.focusedProcessId
            && selectedSource != nil
    }

    private func applySuspension() {
        lifecycle.setSuspended(hidden || shouldHideForFocus || sourceManager.isSleeping)
    }
}
