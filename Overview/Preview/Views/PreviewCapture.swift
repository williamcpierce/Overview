/*
 Preview/Views/PreviewCaptureView.swift
 Overview

 Created by William Pierce on 10/13/24.

 Renders the captured source window content with configurable overlays for
 focus borders and window titles.
*/

import Defaults
import SwiftUI

struct PreviewCapture: View {
    @ObservedObject private var captureCoordinator: CaptureCoordinator
    /// Hold the last good frame so brief reconnects do not flash the grey placeholder.
    @State private var lastFrame: CapturedFrame?

    @Default(.windowOpacity) private var windowOpacity

    init(captureCoordinator: CaptureCoordinator) {
        self.captureCoordinator = captureCoordinator
    }

    var body: some View {
        Group {
            if let frame = captureCoordinator.capturedFrame ?? retainedFrame {
                previewContent(for: frame)
            } else {
                loadingPlaceholder
            }
        }
        .onReceive(captureCoordinator.$capturedFrame) { frame in
            if let frame { lastFrame = frame }
        }
        .onChange(of: captureCoordinator.state) { _, state in
            switch state {
            case .idle, .failed, .permissionRequired:
                if captureCoordinator.capturedFrame == nil { lastFrame = nil }
            case .starting, .running, .paused, .reconnecting:
                break
            }
        }
    }

    private var retainedFrame: CapturedFrame? {
        switch captureCoordinator.state {
        case .starting, .reconnecting, .paused, .running:
            return lastFrame
        case .idle, .failed, .permissionRequired:
            return nil
        }
    }

    // MARK: - View Components

    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(.regularMaterial)
    }

    private func previewContent(for frame: CapturedFrame) -> some View {
        Capture(frame: frame)
            .overlay(FocusBorderOverlay(isWindowFocused: captureCoordinator.isSourceWindowFocused))
            .overlay(
                TitleOverlay(
                    windowTitle: captureCoordinator.sourceIdentity?.label ?? captureCoordinator.sourceWindowTitle,
                    applicationTitle: captureCoordinator.sourceApplicationTitle)
            )
            .opacity(windowOpacity)
    }
}
