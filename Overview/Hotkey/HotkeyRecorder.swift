/*
 Hotkey/HotkeyRecorder.swift
 Overview

 Created by William Pierce on 12/8/24.

 Records keyboard input to create hotkey bindings, managing the recording state
 and keyboard event monitoring
*/

import SwiftUI

struct HotkeyRecorder: NSViewRepresentable {
    // Dependencies
    @Binding var shortcut: HotkeyBinding?

    // Public Properties
    let sourceTitle: String

    func makeNSView(context: Context) -> NSButton {
        let recordingButton = NSButton(frame: .zero)
        recordingButton.bezelStyle = .rounded
        recordingButton.setButtonType(.momentaryPushIn)
        recordingButton.title = shortcut?.hotkeyDisplayString ?? "Click to record shortcut"
        recordingButton.target = context.coordinator
        recordingButton.action = #selector(Coordinator.buttonClicked(_:))
        recordingButton.translatesAutoresizingMaskIntoConstraints = false
        return recordingButton
    }

    func updateNSView(_ button: NSButton, context: Context) {
        button.title = shortcut?.hotkeyDisplayString ?? "Click to record shortcut"
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        private let logger = AppLogger.hotkeys
        private var activeModifierKeys: NSEvent.ModifierFlags = []
        private var isRecordingActive: Bool = false
        private var keyboardMonitor: Any?
        private var parent: HotkeyRecorder

        init(_ parent: HotkeyRecorder) {
            self.parent = parent
            super.init()
            logger.debug("Initializing recorder for source window: '\(parent.sourceTitle)'")
        }

        deinit {
            endRecordingSession()
            logger.debug("Cleaning up recorder for source window: '\(parent.sourceTitle)'")
        }

        // MARK: - Event Handling

        @objc func buttonClicked(_ sender: NSButton) {
            if isRecordingActive {
                endRecordingSession()
                sender.title = parent.shortcut?.hotkeyDisplayString ?? "Click to record shortcut"
            } else {
                beginRecordingSession(sender)
                sender.title = "Type shortcut..."
            }
        }

        private func beginRecordingSession(_ sender: NSButton) {
            guard keyboardMonitor == nil else { return }

            isRecordingActive = true
            activeModifierKeys = []

            keyboardMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.keyDown, .keyUp, .flagsChanged]
            ) { [weak self] event in
                self?.processKeyboardEvent(event)
                return nil
            }

            if keyboardMonitor == nil {
                logger.error("Failed to create keyboard event monitor")
            } else {
                logger.debug("Started recording session for '\(parent.sourceTitle)'")
            }
        }

        private func endRecordingSession() {
            if let monitor: Any = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
                keyboardMonitor = nil
                logger.debug("Ended recording session")
            }
            isRecordingActive = false
            activeModifierKeys = []
        }

        private func processKeyboardEvent(_ event: NSEvent) {
            switch event.type {
            case .flagsChanged:
                updateModifierState(event)
            case .keyDown where isRecordingActive:
                processKeyPress(event)
            default:
                break
            }
        }

        private func updateModifierState(_ event: NSEvent) {
            activeModifierKeys = event.modifierFlags.intersection([
                .command, .control, .option, .shift,
            ])
        }

        private func processKeyPress(_ event: NSEvent) {
            let securityRequiredModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
            guard !securityRequiredModifiers.intersection(activeModifierKeys).isEmpty else {
                logger.warning("Rejected key press without required security modifiers")
                return
            }

            createHotkeyBinding(from: event)
            endRecordingSession()
        }

        private func createHotkeyBinding(from event: NSEvent) {
            parent.shortcut = HotkeyBinding(
                sourceTitle: parent.sourceTitle,
                keyCode: Int(event.keyCode),
                modifiers: activeModifierKeys
            )
            logger.info(
                "Created hotkey binding: \(parent.shortcut?.hotkeyDisplayString ?? "unknown")")
        }
    }
}

// MARK: - Error Definitions

enum ShortcutRecordingError: LocalizedError {
    case invalidModifiers
    case monitoringFailed

    var errorDescription: String? {
        switch self {
        case .invalidModifiers:
            return "Invalid modifier key combination"
        case .monitoringFailed:
            return "Failed to start keyboard monitoring"
        }
    }
}
