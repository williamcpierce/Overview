/*
 HotkeyRecorder.swift
 Overview

 Created by William Pierce on 12/8/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import OSLog
import SwiftUI

struct HotkeyRecorder: NSViewRepresentable {
    let logger = Logger(
        subsystem: "com.Overview.HotkeyRecorder",
        category: "KeyboardEvents"
    )

    @Binding var shortcut: HotkeyBinding?

    let windowTitle: String
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)

        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)

        button.title = shortcut?.hotkeyDisplayString ?? "Click to record shortcut"

        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked(_:))

        button.translatesAutoresizingMaskIntoConstraints = false

        logger.debug("Created recorder button for window: '\(windowTitle)'")
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        button.title = shortcut?.hotkeyDisplayString ?? "Click to record shortcut"
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: HotkeyRecorder
        private let logger: Logger
        var isRecording = false
        var currentModifiers: NSEvent.ModifierFlags = []
        var monitor: Any?

        init(_ parent: HotkeyRecorder) {
            self.parent = parent
            self.logger = parent.logger
            super.init()
        }

        @objc func buttonClicked(_ sender: NSButton) {
            if isRecording {
                stopRecording()
                sender.title = parent.shortcut?.hotkeyDisplayString ?? "Click to record shortcut"
                logger.debug("Recording stopped for window: '\(self.parent.windowTitle)'")
            } else {
                startRecording(sender)
                sender.title = "Type shortcut..."
                logger.debug("Recording started for window: '\(self.parent.windowTitle)'")
            }
        }

        func startRecording(_ sender: NSButton) {
            guard monitor == nil else { return }
            isRecording = true
            currentModifiers = []

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged])
            { [weak self] event in
                self?.handleKeyEvent(event)
                return nil
            }

            if monitor == nil {
                logger.error("Failed to create event monitor")
            }
        }

        func stopRecording() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
                logger.debug("Event monitor removed")
            }
            isRecording = false
            currentModifiers = []
        }

        func handleKeyEvent(_ event: NSEvent) {
            switch event.type {
            case .flagsChanged:
                handleModifierChange(event)
            case .keyDown where isRecording:
                handleKeyPress(event)
            default:
                break
            }
        }

        private func handleModifierChange(_ event: NSEvent) {
            currentModifiers = event.modifierFlags.intersection([
                .command, .control, .option, .shift,
            ])
            let modifierString: String = currentModifiers.rawValue.description
            logger.debug("Modifier state updated: \(modifierString)")
        }

        private func handleKeyPress(_ event: NSEvent) {
            let requiredModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
            guard !requiredModifiers.intersection(currentModifiers).isEmpty else {
                logger.warning("Key press ignored - no required modifiers")
                return
            }

            createBinding(for: event)
            stopRecording()
        }

        private func createBinding(for event: NSEvent) {
            parent.shortcut = HotkeyBinding(
                windowTitle: parent.windowTitle,
                keyCode: Int(event.keyCode),
                modifiers: currentModifiers
            )
            logger.info("Created binding for window '\(self.parent.windowTitle)'")
        }

        deinit {
            stopRecording()
        }
    }
}

enum ShortcutRecordingError: LocalizedError {
    case monitoringFailed
    case invalidModifiers

    var errorDescription: String? {
        switch self {
        case .monitoringFailed:
            return "Failed to start keyboard monitoring"
        case .invalidModifiers:
            return "Invalid modifier key combination"
        }
    }
}
