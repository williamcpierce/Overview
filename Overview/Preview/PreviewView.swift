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
    @State private var isPreviewVisible: Bool = false
    @State private var previewAspectRatio: CGFloat = 0
    @State private var isInitialBindingInProgress: Bool = false

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
            
            // Set the binding flag if we have an initial title
            if let title = initialBoundTitle, !title.isEmpty {
                isInitialBindingInProgress = true
                // Make sure the visibility is updated immediately
                updatePreviewVisibility()
            }
            
            await previewManager.initializeCaptureSystem(captureCoordinator)
            
            // Try to bind to the initial title if provided, but wait for sources to load first
            if let title = initialBoundTitle {
                logger.info("Will attempt to bind to initial title: '\(title)' after sources load")
                // We need to wait for sources to load before trying to bind
                await previewManager.updateAvailableSources()
                bindToTitle(title)
            } else {
                isInitialBindingInProgress = false
                updatePreviewVisibility()
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
        
        // Debug log available sources
        logger.debug("Available sources count: \(previewManager.availableSources.count)")
        for source in previewManager.availableSources {
            logger.debug("Available source: '\(source.title ?? "untitled")' from \(source.owningApplication?.applicationName ?? "unknown")")
        }
        
        // Check if this source is currently available
        if let source = previewManager.availableSources.first(where: {
            guard let sourceTitle = $0.title else { return false }
            let matches = sourceTitle == title
            if matches {
                logger.debug("Found matching source: '\(sourceTitle)'")
            }
            return matches
        }) {
            // Source is available, start capture
            logger.info("Found source for binding: '\(title)', starting capture")
            previewManager.startSourcePreview(captureCoordinator: captureCoordinator, source: source)
            isInitialBindingInProgress = false // Clear binding state when we find the source
        } else {
            // Source not available, enter waiting mode
            logger.info("Source not available, entering waiting mode for: '\(title)'")
            isTitleWaiting = true
            waitingForTitle = title
            
            // We'll check for the source when availableSources changes
            Task {
                // Force refresh the source list
                logger.debug("Forcing source list refresh to find: '\(title)'")
                await previewManager.updateAvailableSources()
                checkForWaitingTitle()
                
                // Set up a timer to periodically check for the source
                setupWaitingTimer()
            }
        }
    }
    
    private func setupWaitingTimer() {
        // Create a timer to periodically check for the waiting source
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            // Check if we're still waiting for a title
            if !self.isTitleWaiting {
                timer.invalidate()
                return
            }
            
            Task {
                await self.previewManager.updateAvailableSources()
                self.checkForWaitingTitle()
            }
        }
    }
    
    private func checkForWaitingTitle() {
        guard isTitleWaiting, let title = waitingForTitle else { return }
        
        logger.debug("Checking for waiting title: '\(title)' among \(previewManager.availableSources.count) sources")
        
        // Debug - list all available sources
        for source in previewManager.availableSources {
            logger.debug("Available source: '\(source.title ?? "untitled")' from \(source.owningApplication?.applicationName ?? "unknown")")
        }
        
        if let source = previewManager.availableSources.first(where: {
            guard let sourceTitle = $0.title else { return false }
            return sourceTitle == title
        }) {
            logger.info("Found source for waiting title: '\(title)'")
            // Use the preview manager to start capture with our source
            previewManager.startSourcePreview(captureCoordinator: captureCoordinator, source: source)
            isTitleWaiting = false
            waitingForTitle = nil
            isInitialBindingInProgress = false // Clear binding state when we find the source
        } else {
            logger.debug("Source for waiting title '\(title)' not found yet")
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
        isInitialBindingInProgress = false // Clear binding state when capture state changes
        updatePreviewVisibility()
        logger.debug("View state updated: selection=\(isSelectionViewVisible)")
    }

    private func updatePreviewVisibility() {
        // If in initial binding state, hide the preview entirely
        if isInitialBindingInProgress {
            isPreviewVisible = false
            return
        }
        
        let alwaysShown =
            isSelectionViewVisible || previewManager.editModeEnabled
            || sourceManager.isOverviewActive

        if alwaysShown {
            Task {
                try await Task.sleep(nanoseconds: 50_000_000)
                isPreviewVisible = true
            }
            return
        }

        let shouldHideForInactiveApps =
            hideInactiveApplications && !captureCoordinator.isSourceAppFocused

        let shouldHideForActiveWindow =
            hideActiveWindow && captureCoordinator.isSourceWindowFocused
        Task {
            try await Task.sleep(nanoseconds: 50_000_000)
            isPreviewVisible = !shouldHideForInactiveApps && !shouldHideForActiveWindow
        }
    }

    private func updatePreviewFrameRate() {
        logger.info("Updating capture frame rate")
        Task {
            await captureCoordinator.updateStreamConfiguration()
        }
    }
}
