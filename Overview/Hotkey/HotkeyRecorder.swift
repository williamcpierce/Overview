/*
 HotkeyRecorder.swift
 Overview

 Created by William Pierce on 12/8/24.

 Provides user interface for recording global keyboard shortcuts, handling system
 keyboard events and coordinating with Overview's hotkey management system.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import AppKit
import OSLog
import SwiftUI

/// Error types that can occur during shortcut recording
enum ShortcutRecordingError: LocalizedError {
    /// Event monitor creation or installation failed
    case monitoringFailed

    /// Required modifier keys not present
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

/// Records keyboard shortcuts for window focus operations in Overview
///
/// Key responsibilities:
/// - Captures system-wide keyboard combinations
/// - Validates modifier key requirements
/// - Provides visual feedback during recording
/// - Coordinates hotkey state with parent views
///
/// Coordinates with:
/// - HotkeyBinding: Creates binding configurations from recorded keys
/// - HotkeyService: Validates against existing registrations
/// - SettingsView: Provides recording interface in preferences
/// - Carbon Event Manager: Processes low-level key events
///
/// Context: Uses NSEvent monitoring instead of Carbon events for recording
/// as it provides better integration with AppKit and automatic memory management.
/// However, the recorded shortcuts are converted to Carbon format for
/// system-wide registration.
struct HotkeyRecorder: NSViewRepresentable {
    // MARK: - Properties

    /// System logger for recording operations
    let logger = Logger(
        subsystem: "com.Overview.HotkeyRecorder",
        category: "KeyboardEvents"
    )

    /// Current keyboard shortcut configuration
    /// - Note: nil indicates no shortcut recorded
    @Binding var shortcut: HotkeyBinding?

    /// Title of window being bound to shortcut
    /// - Note: Used to create HotkeyBinding when recording completes
    let windowTitle: String

    // MARK: - NSViewRepresentable Implementation

    /// Creates button for initiating shortcut recording
    ///
    /// Flow:
    /// 1. Creates styled NSButton instance
    /// 2. Configures initial display state
    /// 3. Sets up action handling
    ///
    /// - Parameter context: View creation context
    /// - Returns: Configured recording button
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)

        // Context: Using rounded style for visual consistency with system preferences
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)

        // Initial state shows current binding or prompt
        button.title = shortcut?.hotkeyDisplayString ?? "Click to record shortcut"

        // Context: Using target-action for reliable event handling
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked(_:))

        logger.debug("Created recorder button for window: '\(windowTitle)'")
        return button
    }

    /// Updates button title when shortcut changes
    ///
    /// Flow:
    /// 1. Retrieves current shortcut state
    /// 2. Updates button display
    ///
    /// - Parameters:
    ///   - button: Button to update
    ///   - context: Update context
    func updateNSView(_ button: NSButton, context: Context) {
        button.title = shortcut?.hotkeyDisplayString ?? "Click to record shortcut"
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    /// Manages button state and keyboard event monitoring
    ///
    /// Key responsibilities:
    /// - Handles recording state transitions
    /// - Processes keyboard events during recording
    /// - Validates modifier requirements
    /// - Creates binding configurations
    ///
    /// Context: Uses NSEvent monitoring for reliable event capture
    /// during recording sessions. Ensures proper cleanup of system
    /// resources when recording completes.
    class Coordinator: NSObject {
        // MARK: - Properties

        /// Parent recorder providing configuration and state updates
        /// - Note: Strong reference maintained by SwiftUI
        var parent: HotkeyRecorder

        /// Logger instance for recording operations
        /// - Note: Stored to avoid repeated parent access
        private let logger: Logger

        /// Whether currently recording a shortcut
        /// - Note: Controls event monitoring state
        var isRecording = false

        /// Current modifier key state
        /// - Note: Updated with each key event
        var currentModifiers: NSEvent.ModifierFlags = []

        /// Active keyboard event monitor
        /// - Note: Stored to enable removal when recording stops
        /// - Warning: Must be removed before deallocation
        var monitor: Any?

        // MARK: - Initialization

        init(_ parent: HotkeyRecorder) {
            self.parent = parent
            self.logger = parent.logger
            super.init()
        }

        // MARK: - Event Handling

        /// Toggles recording state when button clicked
        ///
        /// Flow:
        /// 1. Validates current state
        /// 2. Updates button appearance
        /// 3. Manages recording session
        ///
        /// - Parameter sender: Button that triggered action
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

        /// Begins keyboard event monitoring session
        ///
        /// Flow:
        /// 1. Validates monitor state
        /// 2. Resets modifier tracking
        /// 3. Installs event monitor
        ///
        /// - Parameter sender: Button that initiated recording
        /// - Warning: Must be balanced with stopRecording call
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

        /// Stops keyboard monitoring and cleans up
        ///
        /// Flow:
        /// 1. Removes event monitor
        /// 2. Resets recording state
        /// 3. Clears modifier tracking
        func stopRecording() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
                logger.debug("Event monitor removed")
            }
            isRecording = false
            currentModifiers = []
        }

        /// Processes keyboard events during recording
        ///
        /// Flow:
        /// 1. Routes event to appropriate handler based on type
        /// 2. Validates recording state
        /// 3. Creates binding if requirements met
        ///
        /// - Parameter event: Keyboard event to process
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

        /// Updates modifier key state
        ///
        /// Flow:
        /// 1. Extracts valid modifier flags
        /// 2. Updates current state
        /// 3. Logs state change
        ///
        /// - Parameter event: Modifier key event
        private func handleModifierChange(_ event: NSEvent) {
            currentModifiers = event.modifierFlags.intersection([
                .command, .control, .option, .shift,
            ])
            let modifierString: String = currentModifiers.rawValue.description
            logger.debug("Modifier state updated: \(modifierString)")
        }

        /// Processes key press events and creates bindings
        ///
        /// Flow:
        /// 1. Validates modifier requirements
        /// 2. Creates binding configuration
        /// 3. Stops recording session
        ///
        /// - Parameter event: Key press event
        private func handleKeyPress(_ event: NSEvent) {
            let requiredModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
            guard !requiredModifiers.intersection(currentModifiers).isEmpty else {
                logger.warning("Key press ignored - no required modifiers")
                return
            }

            createBinding(for: event)
            stopRecording()
        }

        /// Creates hotkey binding from current state
        ///
        /// Flow:
        /// 1. Creates binding with current configuration
        /// 2. Updates parent shortcut state
        /// 3. Logs binding creation
        ///
        /// - Parameter event: Triggering key event
        private func createBinding(for event: NSEvent) {
            parent.shortcut = HotkeyBinding(
                windowTitle: parent.windowTitle,
                keyCode: Int(event.keyCode),
                modifiers: currentModifiers
            )
            logger.info("Created binding for window '\(self.parent.windowTitle)'")
        }

        /// Cleanup event monitor on deallocation
        /// - Warning: Required to prevent monitor leaks
        deinit {
            stopRecording()
        }
    }
}
