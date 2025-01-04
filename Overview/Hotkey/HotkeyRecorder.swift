/*
 Hotkey/HotkeyRecorder.swift
 Overview

 Created by William Pierce on 12/8/24.
*/

import SwiftUI

struct HotkeyRecorder: NSViewRepresentable {
    @Binding var shortcut: HotkeyBinding?
    let windowTitle: String

    func makeNSView(context: Context) -> NSButton {
        let recordingButton: NSButton = NSButton(frame: .zero)
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

    final class Coordinator: NSObject {
        private let logger = AppLogger.hotkeys
        private var activeModifierKeys: NSEvent.ModifierFlags = []
        private var isRecordingActive: Bool = false
        private var keyboardMonitor: Any?
        private var parent: HotkeyRecorder

        init(_ parent: HotkeyRecorder) {
            self.parent = parent
            super.init()
            logger.debug("Initializing recorder for window: '\(parent.windowTitle)'")
        }

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
                logger.error("Event monitor creation failed")
            }
        }

        private func endRecordingSession() {
            if let monitor: Any = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
                keyboardMonitor = nil
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
                logger.warning("Rejected key press without required modifiers")
                return
            }

            createHotkeyBinding(from: event)
            endRecordingSession()
        }

        private func createHotkeyBinding(from event: NSEvent) {
            parent.shortcut = HotkeyBinding(
                windowTitle: parent.windowTitle,
                keyCode: Int(event.keyCode),
                modifiers: activeModifierKeys
            )
        }

        deinit {
            endRecordingSession()
        }
    }
}

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
