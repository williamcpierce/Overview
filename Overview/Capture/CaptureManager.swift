/*
 CaptureManager.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import Combine
import OSLog
import ScreenCaptureKit

@MainActor
class CaptureManager: ObservableObject {
    @Published private(set) var capturedFrame: CapturedFrame?
    @Published private(set) var isCapturing = false
    @Published private(set) var isSourceWindowFocused = false
    @Published private(set) var windowTitle: String?
    @Published var selectedWindow: SCWindow? {
        didSet {
            windowTitle = selectedWindow?.title
            if let window = selectedWindow {
                subscribeToWindowUpdates(window)
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private var captureTask: Task<Void, Never>?
    private let windowManager = WindowManager.shared
    private let appSettings: AppSettings
    private let captureEngine: CaptureEngine
    private let streamConfig: StreamConfigurationService

    init(
        appSettings: AppSettings,
        captureEngine: CaptureEngine = CaptureEngine(),
        streamConfig: StreamConfigurationService = StreamConfigurationService()
    ) {
        self.appSettings = appSettings
        self.captureEngine = captureEngine
        self.streamConfig = streamConfig
        setupObservers()
    }

    func requestPermission() async throws {
        try await ShareableContentService().requestPermission()
    }

    func updateAvailableWindows() async {
        await windowManager.updateWindowState()
    }

    func getAvailableWindows() -> [SCWindow] {
        Task {
            await windowManager.getAvailableWindows()
        }
        return []
    }

    func startCapture() async throws {
        guard !isCapturing else { return }
        guard let window = selectedWindow else {
            throw CaptureError.noWindowSelected
        }

        let (config, filter) = streamConfig.createConfiguration(
            window, frameRate: appSettings.frameRate)
        let frameStream = captureEngine.startCapture(configuration: config, filter: filter)

        await startCaptureTask(frameStream: frameStream)
        isCapturing = true
    }

    func stopCapture() async {
        guard isCapturing else { return }

        captureTask?.cancel()
        captureTask = nil
        await captureEngine.stopCapture()

        isCapturing = false
        capturedFrame = nil
    }

    func focusWindow(isEditModeEnabled: Bool) {
        guard let window = selectedWindow,
            let title = window.title,
            !isEditModeEnabled
        else { return }

        windowManager.focusWindow(withTitle: title)
    }

    private func startCaptureTask(frameStream: AsyncThrowingStream<CapturedFrame, Error>) async {
        captureTask?.cancel()

        captureTask = Task { @MainActor in
            do {
                for try await frame in frameStream {
                    self.capturedFrame = frame
                }
            } catch {
                await self.handleCaptureError(error)
            }
        }
    }

    private func subscribeToWindowUpdates(_ window: SCWindow) {
        windowManager.subscribeToWindowState(window) { [weak self] isFocused, title in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if self.windowTitle != title {
                    self.windowTitle = title
                }

                if self.isSourceWindowFocused != isFocused {
                    self.isSourceWindowFocused = isFocused
                }
            }
        }
    }

    private func handleCaptureError(_ error: Error) async {
        await stopCapture()
    }

    private func setupObservers() {
        if let window = selectedWindow {
            windowManager.subscribeToWindowState(window) { [weak self] isFocused, title in
                self?.isSourceWindowFocused = isFocused
                self?.windowTitle = title
            }
        }

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
        guard let window = selectedWindow else { return }
        isSourceWindowFocused = windowManager.isWindowFocused(window)
    }

    private func updateWindowTitle() async {
        windowTitle = selectedWindow?.title
    }

    private func updateStreamConfiguration() async {
        guard isCapturing, let window = selectedWindow else { return }
        try? await streamConfig.updateConfiguration(
            captureEngine.stream, window, frameRate: appSettings.frameRate)
    }
}

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
