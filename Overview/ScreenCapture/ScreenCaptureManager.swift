/*
 ScreenCaptureManager.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import Foundation
import ScreenCaptureKit
import CoreImage
import AppKit
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
class ScreenCaptureManager: NSObject, ObservableObject {
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
    private let captureEngine: CaptureEngine
    private let logger = Logger(subsystem: "com.Overview.ScreenCaptureManager", category: "ScreenCapture")
    private let appSettings: AppSettings
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Services
    private let windowFilterService: WindowFilterService
    private let windowObserverService: WindowObserverService
    private let streamConfigService: StreamConfigurationService
    private let windowFocusService: WindowFocusService
    private let windowTitleService: WindowTitleService
    private let shareableContentService: ShareableContentService
    private let captureTaskManager: CaptureTaskManager
    
    init(
        appSettings: AppSettings,
        captureEngine: CaptureEngine = CaptureEngine(),
        windowFilterService: WindowFilterService = DefaultWindowFilterService(),
        windowObserverService: WindowObserverService = DefaultWindowObserverService(),
        streamConfigService: StreamConfigurationService = DefaultStreamConfigurationService(),
        windowFocusService: WindowFocusService = DefaultWindowFocusService(),
        windowTitleService: WindowTitleService = DefaultWindowTitleService(),
        shareableContentService: ShareableContentService = DefaultShareableContentService(),
        captureTaskManager: CaptureTaskManager = DefaultCaptureTaskManager()
    ) {
        self.appSettings = appSettings
        self.captureEngine = captureEngine
        self.windowFilterService = windowFilterService
        self.windowObserverService = windowObserverService
        self.streamConfigService = streamConfigService
        self.windowFocusService = windowFocusService
        self.windowTitleService = windowTitleService
        self.shareableContentService = shareableContentService
        self.captureTaskManager = captureTaskManager
        
        super.init()
        
        setupCaptureHandlers()
        setupObservers()
    }

    // MARK: - Public Methods
    func requestPermission() async throws {
        try await shareableContentService.requestPermission()
    }
    
    func updateAvailableWindows() async {
        do {
            let windows = try await shareableContentService.getAvailableWindows()
            self.availableWindows = windowFilterService.filterWindows(windows)
        } catch {
            logger.error("Failed to get available windows: \(error.localizedDescription)")
        }
    }
    
    func startCapture() async throws {
        guard !isCapturing else { return }
        guard let window = selectedWindow else {
            throw CaptureError.noWindowSelected
        }

        let config = streamConfigService.createConfiguration(for: window, frameRate: appSettings.frameRate)
        let filter = SCContentFilter(desktopIndependentWindow: window)
        
        await captureTaskManager.startCapture(using: captureEngine, config: config, filter: filter)
        isCapturing = true
    }
    
    func stopCapture() async {
        guard isCapturing else { return }
        
        await captureTaskManager.stopCapture()
        await captureEngine.stopCapture()
        
        isCapturing = false
        capturedFrame = nil
    }
    
    func focusWindow(isEditModeEnabled: Bool) {
        guard let window = selectedWindow else { return }
        windowFocusService.focusWindow(window: window, isEditModeEnabled: isEditModeEnabled)
    }
    
    // MARK: - Private Methods
    private func setupCaptureHandlers() {
        captureTaskManager.onFrame = { [weak self] frame in
            Task { @MainActor [weak self] in
                self?.capturedFrame = frame
            }
        }
        
        captureTaskManager.onError = { [weak self] _ in
            Task { [weak self] in
                await self?.stopCapture()
            }
        }
    }
    
    private func setupObservers() {
        windowObserverService.onFocusStateChanged = { [weak self] in
            await self?.updateFocusState()
        }
        windowObserverService.onWindowTitleChanged = { [weak self] in
            await self?.updateWindowTitle()
        }
        windowObserverService.startObserving()
        
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
        isSourceWindowFocused = await windowFocusService.updateFocusState(for: selectedWindow)
    }
    
    private func updateWindowTitle() async {
        windowTitle = await windowTitleService.updateWindowTitle(for: selectedWindow)
    }
    
    private func updateStreamConfiguration() async {
        guard isCapturing, let window = selectedWindow else { return }
        
        do {
            try await streamConfigService.updateConfiguration(
                captureEngine.stream,
                for: window,
                frameRate: appSettings.frameRate
            )
        } catch {
            logger.error("Failed to update stream configuration: \(error.localizedDescription)")
        }
    }
}
