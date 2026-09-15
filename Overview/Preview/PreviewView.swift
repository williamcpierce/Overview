/*
 Preview/PreviewView.swift
 Overview

 Coordinates capture state, source-group visibility, and preview interactions.
*/
import Defaults
import SwiftUI

struct PreviewView: View {
    @ObservedObject private var previewManager: PreviewManager
    @ObservedObject private var sourceManager: SourceManager
    @ObservedObject private var permissionManager: PermissionManager
    @ObservedObject private var captureCoordinator: CaptureCoordinator
    private let logger = AppLogger.interface
    let onClose: () -> Void

    @State private var isSelectionViewVisible: Bool = true
    @State private var isPreviewVisible: Bool = true
    @State private var previewAspectRatio: CGFloat = 0
    @State private var showSourceGroupEditor = false
    /// Tracks whether this preview ever had a source, so close-on-stop does not kill brand-new windows.
    @State private var hadAssignment = false

    @Default(.captureFrameRate) private var captureFrameRate
    @Default(.hideInactiveApplications) private var hideInactiveApplications
    @Default(.closeOnCaptureStop) private var closeOnCaptureStop

    init(
        previewManager: PreviewManager,
        sourceManager: SourceManager,
        permissionManager: PermissionManager,
        captureCoordinator: CaptureCoordinator,
        onClose: @escaping () -> Void
    ) {
        self.previewManager = previewManager
        self.sourceManager = sourceManager
        self.permissionManager = permissionManager
        self.captureCoordinator = captureCoordinator
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { geometry in
            previewContentStack(in: geometry)
                .background(PreviewSizeReader { captureCoordinator.setPixelSize($0) })
                .frame(width: geometry.size.width, height: geometry.size.height)
                // Fill the window; NSWindow.contentAspectRatio owns the locked scale when a source is set.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(previewBackgroundLayer)
                .background(windowConfigurationLayer)
                .overlay {
                    // Capture click-to-focus only when showing live content outside edit mode.
                    if !previewManager.editModeEnabled && !isSelectionViewVisible {
                        previewInteractionLayer
                    }
                }
                .overlay {
                    // Edit mode must sit above pickers/status chrome so empty windows can drag.
                    if previewManager.editModeEnabled {
                        previewInteractionLayer
                    }
                }
                .contextMenu {
                    Button(previewManager.editModeEnabled ? "Exit Edit Mode" : "Edit Mode") {
                        previewManager.editModeEnabled.toggle()
                    }
                    Divider()
                    TextField(
                        "Preview label",
                        text: Binding(
                            get: { captureCoordinator.sourceIdentity?.label ?? "" },
                            set: { captureCoordinator.setLabel($0) }
                        )
                    )
                    Button("Manage Source Group…") { showSourceGroupEditor = true }
                    Toggle(
                        "Hide When Focused",
                        isOn: Binding(
                            get: { captureCoordinator.effectiveHideWhenFocused },
                            set: { captureCoordinator.setHideWhenFocused($0) }
                        )
                    )
                    .disabled(captureCoordinator.sources.count > 1)
                }
                .overlay(alignment: .bottomTrailing) {
                    EditIndicatorOverlay(isEditModeEnabled: previewManager.editModeEnabled)
                }
                .overlay(alignment: .topTrailing) {
                    CloseButtonOverlay(
                        isEditModeEnabled: previewManager.editModeEnabled,
                        isSelectionViewVisible: isSelectionViewVisible,
                        teardownCapture: teardownCapture,
                        onClose: onClose
                    )
                }
                .opacity(isPreviewVisible ? 1 : 0)
        }
        .frame(minWidth: 100, minHeight: 50)
        .onAppear(perform: setupCapture)
        .onDisappear { Task { await captureCoordinator.close() } }
        .sheet(isPresented: $showSourceGroupEditor) {
            SourceGroupEditor(
                captureCoordinator: captureCoordinator,
                previewManager: previewManager
            )
        }
        .onChange(of: captureCoordinator.capturedFrame?.size) { oldSize, newSize in
            updatePreviewDimensions(from: oldSize, to: newSize)
        }
        .onChange(of: captureCoordinator.state) { updateViewState() }
        .onChange(of: captureCoordinator.shouldHideForFocus) { updatePreviewVisibility() }
        .onChange(of: captureCoordinator.hideWhenFocused) { updatePreviewVisibility() }
        .onChange(of: previewManager.editModeEnabled) { updatePreviewVisibility() }
        .onChange(of: captureCoordinator.isSourceAppFocused) { updatePreviewVisibility() }
        .onChange(of: captureCoordinator.isSourceWindowFocused) { updatePreviewVisibility() }
        .onChange(of: sourceManager.isOverviewActive) { updatePreviewVisibility() }
        .onChange(of: hideInactiveApplications) { updatePreviewVisibility() }
        .onChange(of: previewManager.hideAllPreviews) { _, hidden in
            captureCoordinator.setHidden(hidden)
            updatePreviewVisibility()
        }
        .onChange(of: captureFrameRate) { updatePreviewFrameRate() }
    }

    private func previewContentStack(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if isSelectionViewVisible {
                PreviewSelection(
                    captureCoordinator: captureCoordinator,
                    previewManager: previewManager
                )
            } else {
                PreviewCapture(captureCoordinator: captureCoordinator)
                    .overlay(alignment: .bottom) {
                        statusOverlay
                    }
            }
        }
    }

    private var previewInteractionLayer: some View {
        WindowInteraction(
            editModeEnabled: $previewManager.editModeEnabled,
            isSelectionViewVisible: $isSelectionViewVisible,
            hideWhenFocused: captureCoordinator.effectiveHideWhenFocused,
            hideWhenFocusedLocked: captureCoordinator.sources.count > 1,
            onEditModeToggle: { previewManager.editModeEnabled.toggle() },
            onSourceWindowFocus: { captureCoordinator.focusSource() },
            onManageSourceGroup: { showSourceGroupEditor = true },
            onToggleHideWhenFocused: {
                // Multi-source groups always swap; only single-source windows can toggle.
                guard captureCoordinator.sources.count <= 1 else { return }
                captureCoordinator.setHideWhenFocused(!captureCoordinator.hideWhenFocused)
            },
            teardownCapture: teardownCapture,
            onClose: onClose
        )
    }

    private var previewBackgroundLayer: some View {
        Rectangle()
            .fill(.regularMaterial)
            .opacity(isSelectionViewVisible ? 1 : 0)
    }

    /// Only show the grey action panel for real problems — not brief start/reconnect flashes.
    @ViewBuilder
    private var statusOverlay: some View {
        if captureCoordinator.shouldHideForFocus {
            EmptyView()
        } else if showsActionableStatus {
            VStack(spacing: 4) {
                Text(captureCoordinator.statusLabel).font(.caption)
                HStack {
                    Button("Retry") { Task { await captureCoordinator.retry() } }
                    Button("Choose Source") { isSelectionViewVisible = true }
                    Button("Source Group…") { showSourceGroupEditor = true }
                }
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(4)
        } else if showsTransientStatus {
            Text(captureCoordinator.statusLabel)
                .font(.caption2)
                .padding(4)
                .background(.regularMaterial.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                .padding(4)
        } else if captureCoordinator.applicationFocusOnly {
            Text("Application active").font(.caption2)
                .padding(4).background(.regularMaterial)
        }
    }

    private var showsActionableStatus: Bool {
        if captureCoordinator.resolutionMessage != nil { return true }
        switch captureCoordinator.state {
        case .failed, .permissionRequired: return true
        case .idle, .starting, .running, .paused, .reconnecting: return false
        }
    }

    private var showsTransientStatus: Bool {
        // Caption only when there is no live frame to cover the gap.
        guard captureCoordinator.capturedFrame == nil else { return false }
        switch captureCoordinator.state {
        case .starting, .reconnecting, .paused: return true
        case .idle, .running, .permissionRequired, .failed: return false
        }
    }

    private var windowConfigurationLayer: some View {
        WindowAccessor(
            aspectRatio: $previewAspectRatio,
            captureCoordinator: captureCoordinator,
            previewManager: previewManager,
            sourceManager: sourceManager
        )
    }

    private func setupCapture() {
        captureCoordinator.beginTracking()
        captureCoordinator.setHidden(previewManager.hideAllPreviews)
        updateViewState()
        Task {
            logger.info("Initializing capture system")
            await previewManager.initializeCaptureSystem(captureCoordinator)
        }
    }

    private func teardownCapture() {
        Task {
            logger.info("Stopping capture system")
            await captureCoordinator.stopCapture()
        }
    }

    private func updatePreviewDimensions(from oldSize: CGSize?, to newSize: CGSize?) {
        guard let size: CGSize = newSize else { return }
        let newRatio: CGFloat = size.width / size.height
        logger.debug("Updating preview dimensions: \(Int(size.width))x\(Int(size.height))")
        previewAspectRatio = newRatio
    }

    private func updateViewState() {
        if captureCoordinator.hasAssignment {
            hadAssignment = true
        }

        // Only close after a real assignment is cleared — never when a fresh window is waiting for a source.
        if closeOnCaptureStop,
           hadAssignment,
           captureCoordinator.state == .idle,
           !captureCoordinator.hasAssignment
        {
            logger.info("Closing preview window on capture stop")
            onClose()
            return
        }

        isSelectionViewVisible = !captureCoordinator.hasAssignment
        updatePreviewVisibility()
        logger.debug("View state updated: selection=\(isSelectionViewVisible)")
    }

    private func updatePreviewVisibility() {
        if previewManager.hideAllPreviews {
            isPreviewVisible = false
            return
        }

        let alwaysShown =
            isSelectionViewVisible || previewManager.editModeEnabled
            || sourceManager.isOverviewActive

        if alwaysShown {
            isPreviewVisible = true
            return
        }

        if captureCoordinator.shouldHideForFocus {
            isPreviewVisible = false
            return
        }

        let shouldHideForInactiveApps =
            hideInactiveApplications && !captureCoordinator.isSourceAppFocused

        isPreviewVisible = !shouldHideForInactiveApps
    }

    private func updatePreviewFrameRate() {
        logger.info("Updating capture frame rate")
        Task { await captureCoordinator.updateStreamConfiguration() }
    }
}
