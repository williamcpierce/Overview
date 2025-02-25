/*
 Preview/PreviewView.swift
 Overview

 Created by William Pierce on 9/15/24.

 The main preview interface, coordinating capture state, window visibility,
 and user interactions across the application's preview functionality.
*/

import SwiftUI

struct PreviewView: View {
    // Dependencies
    @ObservedObject private var previewManager: PreviewManager
    @ObservedObject private var sourceManager: SourceManager
    @ObservedObject private var permissionManager: PermissionManager
    @StateObject private var captureCoordinator: CaptureCoordinator
    private let logger = AppLogger.interface
    let onClose: () -> Void
    
    // Title binding
    let initialBoundTitle: String?
    let onTitleChange: ((String?) -> Void)?
    @State private var isTitleWaiting: Bool = false
    @State private var waitingForTitle: String?

    // Private State
    @State private var isSelectionViewVisible: Bool = true
    @State private var isPreviewVisible: Bool = true
    @State private var previewAspectRatio: CGFloat = 0

    // Preview Settings
    @AppStorage(PreviewSettingsKeys.captureFrameRate)
    private var captureFrameRate = PreviewSettingsKeys.defaults.captureFrameRate
    @AppStorage(PreviewSettingsKeys.hideInactiveApplications)
    private var hideInactiveApplications = PreviewSettingsKeys.defaults.hideInactiveApplications
    @AppStorage(PreviewSettingsKeys.hideActiveWindow)
    private var hideActiveWindow = PreviewSettingsKeys.defaults.hideActiveWindow

    // Window Settings
    @AppStorage(WindowSettingsKeys.closeOnCaptureStop)
    private var closeOnCaptureStop = WindowSettingsKeys.defaults.closeOnCaptureStop

    init(
        previewManager: PreviewManager,
        sourceManager: SourceManager,
        permissionManager: PermissionManager,
        initialBoundTitle: String? = nil,
        onTitleChange: ((String?) -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.previewManager = previewManager
        self.sourceManager = sourceManager
        self.permissionManager = permissionManager
        self.initialBoundTitle = initialBoundTitle
        self.onTitleChange = onTitleChange
        self.onClose = onClose
        self._captureCoordinator = StateObject(
            wrappedValue: CaptureCoordinator(
                sourceManager: sourceManager, permissionManager: permissionManager)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            previewContentStack(in: geometry)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .aspectRatio(previewAspectRatio, contentMode: .fit)
                .background(previewBackgroundLayer)
                .background(windowConfigurationLayer)
                .overlay(previewInteractionLayer)
                .overlay(EditIndicatorOverlay(isEditModeEnabled: previewManager.editModeEnabled))
                .overlay(
                    CloseButtonOverlay(
                        isEditModeEnabled: previewManager.editModeEnabled,
                        teardownCapture: teardownCapture,
                        onClose: onClose
                    )
                )
                .overlay(waitingModeOverlay)
                .opacity(isPreviewVisible ? 1 : 0)
        }
        .frame(minWidth: 100, minHeight: 50)
        .onAppear(perform: setupCapture)
        .onDisappear(perform: teardownCapture)
        .onChange(of: captureCoordinator.capturedFrame?.size) { newSize in
            updatePreviewDimensions(from: captureCoordinator.capturedFrame?.size, to: newSize)
        }
        .onChange(of: captureCoordinator.isCapturing) { _ in
            updateViewState()
        }
        .onChange(of: previewManager.editModeEnabled) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: captureCoordinator.isSourceAppFocused) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: captureCoordinator.isSourceWindowFocused) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: sourceManager.isOverviewActive) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: hideInactiveApplications) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: hideActiveWindow) { _ in
            updatePreviewVisibility()
        }
        .onChange(of: captureFrameRate) { _ in
            updatePreviewFrameRate()
        }
        .onChange(of: captureCoordinator.sourceWindowTitle) { newTitle in
            onTitleChange?(newTitle)
            
            // If we're waiting for a title and it matches
            if isTitleWaiting,
               let waitingTitle = waitingForTitle,
               let newTitle = newTitle,
               newTitle == waitingTitle {
                logger.info("Found waiting title: '\(waitingTitle)'")
                isTitleWaiting = false
                waitingForTitle = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bindWindowToTitle)) { notification in
            guard let window = notification.object as? NSWindow,
                  window.contentView?.ancestorOrSelf(ofType: NSHostingView<PreviewView>.self) != nil,
                  let title = notification.userInfo?["title"] as? String
            else { return }
            
            bindToTitle(title)
        }
    }

    // MARK: - View Components

    private func previewContentStack(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if isSelectionViewVisible {
                PreviewSelection(
                    captureCoordinator: captureCoordinator,
                    previewManager: previewManager
                )
            } else {
                PreviewCapture(
                    captureCoordinator: captureCoordinator
                )
            }
        }
    }

    private var previewInteractionLayer: some View {
        WindowInteraction(
            editModeEnabled: $previewManager.editModeEnabled,
            isSelectionViewVisible: $isSelectionViewVisible,
            onEditModeToggle: { previewManager.editModeEnabled.toggle() },
            onSourceWindowFocus: { captureCoordinator.focusSource() },
            teardownCapture: teardownCapture,
            onClose: onClose
        )
    }
    
    private var waitingModeOverlay: some View {
        Group {
            if isTitleWaiting, let title = waitingForTitle {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Waiting for window: '\(title)'")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }

    private var previewBackgroundLayer: some View {
        Rectangle()
            .fill(.regularMaterial)
            .opacity(isSelectionViewVisible ? 1 : 0)
    }

    private var windowConfigurationLayer: some View {
        WindowAccessor(
            aspectRatio: $previewAspectRatio,
            captureCoordinator: captureCoordinator,
            previewManager: previewManager,
            sourceManager: sourceManager
        )
    }

    // MARK: - Lifecycle Methods

    private func setupCapture() {
        Task {
            logger.info("Initializing capture system")
            await previewManager.initializeCaptureSystem(captureCoordinator)
            
            // Try to bind to the initial title if provided
            if let title = initialBoundTitle {
                bindToTitle(title)
            }
        }
    }

    private func teardownCapture() {
        Task {
            logger.info("Stopping capture system")
            await captureCoordinator.stopCapture()
        }
    }
    
    // MARK: - Title Binding
    
    private func bindToTitle(_ title: String) {
        logger.info("Attempting to bind window to title: '\(title)'")
        
        // Check if this source is currently available
        if let source = previewManager.availableSources.first(where: { $0.title == title }) {
            // Source is available, start capture
            logger.info("Found source for binding: '\(title)'")
            previewManager.startSourcePreview(captureCoordinator: captureCoordinator, source: source)
        } else {
            // Source not available, enter waiting mode
            logger.info("Source not available, entering waiting mode for: '\(title)'")
            isTitleWaiting = true
            waitingForTitle = title
            
            // We'll check for the source when availableSources changes
            Task {
                await previewManager.updateAvailableSources()
                checkForWaitingTitle()
            }
        }
    }
    
    private func checkForWaitingTitle() {
        guard isTitleWaiting, let title = waitingForTitle else { return }
        
        if let source = previewManager.availableSources.first(where: { $0.title == title }) {
            logger.info("Found source for waiting title: '\(title)'")
            previewManager.startSourcePreview(captureCoordinator: captureCoordinator, source: source)
            isTitleWaiting = false
            waitingForTitle = nil
        }
    }

    // MARK: - State Updates

    private func updatePreviewDimensions(from oldSize: CGSize?, to newSize: CGSize?) {
        guard let size: CGSize = newSize else { return }
        let newRatio: CGFloat = size.width / size.height
        logger.debug("Updating preview dimensions: \(Int(size.width))x\(Int(size.height))")
        previewAspectRatio = newRatio
    }

    private func updateViewState() {
        if !captureCoordinator.isCapturing && closeOnCaptureStop {
            logger.info("Closing preview window on capture stop")
            onClose()
        }

        isSelectionViewVisible = !captureCoordinator.isCapturing
        updatePreviewVisibility()
        logger.debug("View state updated: selection=\(isSelectionViewVisible)")
    }

    private func updatePreviewVisibility() {
        let alwaysShown =
            isSelectionViewVisible || previewManager.editModeEnabled
            || sourceManager.isOverviewActive

        if alwaysShown {
            isPreviewVisible = true
            return
        }

        let shouldHideForInactiveApps =
            hideInactiveApplications && !captureCoordinator.isSourceAppFocused

        let shouldHideForActiveWindow =
            hideActiveWindow && captureCoordinator.isSourceWindowFocused

        isPreviewVisible = !shouldHideForInactiveApps && !shouldHideForActiveWindow
    }

    private func updatePreviewFrameRate() {
        logger.info("Updating capture frame rate")
        Task {
            await captureCoordinator.updateStreamConfiguration()
        }
    }
}
