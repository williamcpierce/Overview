/*
 ScreenCaptureManager.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit
import Combine
import OSLog

enum CaptureError: LocalizedError {
    case permissionDenied
    case noWindowSelected
    case captureStreamFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen capture permission was denied"
        case .noWindowSelected:
            return "No window is selected for capture"
        case .captureStreamFailed(let error):
            return "Capture failed: \(error.localizedDescription)"
        }
    }
}

@MainActor
class ScreenCaptureManager: ObservableObject {
    // MARK: - Published Properties
    @Published var capturedFrame: CapturedFrame?
    @Published var availableWindows: [SCWindow] = []
    @Published var isCapturing = false
    @Published var isSourceWindowFocused = false
    @Published var windowTitle: String?
    @Published var selectedWindow: SCWindow? {
        didSet {
            windowTitle = selectedWindow?.title
            Task { await updateFocusState() }
        }
    }
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.Overview.ScreenCaptureManager", category: "ScreenCapture")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependencies
    private let appSettings: AppSettings
    private let captureEngine: CaptureEngine
    private let captureTask: CaptureTaskManager
    private let streamConfig: StreamConfigurationService
    private let windowFilter: WindowFilterService
    private let windowFocus: WindowFocusService
    private let titleService: WindowTitleService
    private let windowObserver: WindowObserverService
    private let shareableContent: ShareableContentService
    
    // MARK: - Initialization
    init(
        appSettings: AppSettings,
        captureEngine: CaptureEngine = CaptureEngine(),
        captureTask: CaptureTaskManager = CaptureTaskManager(),
        streamConfig: StreamConfigurationService = StreamConfigurationService(),
        windowFilter: WindowFilterService = WindowFilterService(),
        windowFocus: WindowFocusService = WindowFocusService(),
        titleService: WindowTitleService = WindowTitleService(),
        windowObserver: WindowObserverService = WindowObserverService(),
        shareableContent: ShareableContentService = ShareableContentService()
    ) {
        self.appSettings = appSettings
        self.captureEngine = captureEngine
        self.captureTask = captureTask
        self.streamConfig = streamConfig
        self.windowFilter = windowFilter
        self.windowFocus = windowFocus
        self.titleService = titleService
        self.windowObserver = windowObserver
        self.shareableContent = shareableContent
        
        setupCaptureHandlers()
        setupObservers()
    }
    
    // MARK: - Public Methods
    func requestPermission() async throws {
        try await shareableContent.requestPermission()
    }
    
    func updateAvailableWindows() async {
        do {
            let windows = try await shareableContent.getAvailableWindows()
            await MainActor.run {
                self.availableWindows = windowFilter.filterWindows(windows)
            }
        } catch {
            logger.error("Failed to get available windows: \(error.localizedDescription)")
        }
    }
    
    func startCapture() async throws {
        guard !isCapturing else { return }
        guard let window = selectedWindow else {
            throw CaptureError.noWindowSelected
        }

        let (config, filter) = streamConfig.createConfiguration(window, frameRate: appSettings.frameRate)
        let frameStream = captureEngine.startCapture(configuration: config, filter: filter)
        await captureTask.startCapture(frameStream: frameStream)
        isCapturing = true
    }
    
    func stopCapture() async {
        guard isCapturing else { return }
        
        await captureTask.stopCapture()
        await captureEngine.stopCapture()
        
        isCapturing = false
        capturedFrame = nil
    }
    
    func focusWindow(isEditModeEnabled: Bool) {
        guard let window = selectedWindow else { return }
        windowFocus.focusWindow(window: window, isEditModeEnabled: isEditModeEnabled)
    }
    
    // MARK: - Private Methods
    private func setupCaptureHandlers() {
        captureTask.onFrame = { [weak self] frame in
            Task { @MainActor [weak self] in
                self?.capturedFrame = frame
            }
        }
        
        captureTask.onError = { [weak self] _ in
            Task { [weak self] in
                await self?.stopCapture()
            }
        }
    }
    
    private func setupObservers() {
        windowObserver.onFocusStateChanged = { [weak self] in
            await self?.updateFocusState()
        }
        
        windowObserver.onWindowTitleChanged = { [weak self] in
            await self?.updateWindowTitle()
        }
        
        windowObserver.startObserving()
        
        appSettings.$frameRate
            .dropFirst()
            .sink { [weak self] _ in
                Task {
                    await self?.updateStreamConfiguration()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateFocusState() async {
        isSourceWindowFocused = await windowFocus.updateFocusState(for: selectedWindow)
    }
    
    private func updateWindowTitle() async {
        windowTitle = await titleService.updateWindowTitle(for: selectedWindow)
    }
    
    private func updateStreamConfiguration() async {
        guard isCapturing, let window = selectedWindow else { return }
        try? await streamConfig.updateConfiguration(captureEngine.stream, window, frameRate: appSettings.frameRate)
    }
}
