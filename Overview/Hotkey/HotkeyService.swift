/*
 Hotkey/HotkeyService.swift
 Overview

 Created by William Pierce on 12/8/24

 Manages system-wide keyboard shortcuts using Carbon Event Manager APIs, providing a
 reliable and efficient implementation of global keyboard shortcuts. Primary coordinator
 for mapping keyboard combinations to window focus operations.
*/

import Carbon
import Cocoa
import SwiftUI

final class HotkeyService {
    static let shared: HotkeyService = HotkeyService()
    private let logger = AppLogger.hotkeys

    /// Maximum concurrent hotkey registrations to prevent resource exhaustion
    private static let registrationLimit = 50

    /// O(1) hotkey event routing by ID
    private var activeHotkeys: [UInt32: (EventHotKeyRef, HotkeyBinding)] = [:]
    private var eventHandlerIdentifier: EventHandlerRef?
    private var nextIdentifier: UInt32 = 1

    /// Thread-safe event processing queue with debounce support
    private let processingQueue = DispatchQueue(label: "com.Overview.HotkeyEventQueue")
    private var previousEvent: HotkeyEventProcessor?

    /// Registered callbacks mapped by object identity to prevent retain cycles
    private var windowFocusCallbacks: [ObjectIdentifier: (String) -> Void] = [:]

    deinit {
        cleanupResources()
    }

    func registerCallback(owner: AnyObject, callback: @escaping (String) -> Void) {
        let identifier = ObjectIdentifier(owner)
        windowFocusCallbacks[identifier] = callback
        logger.debug("Registered callback: \(identifier)")
    }

    func removeCallback(for owner: AnyObject) {
        let identifier = ObjectIdentifier(owner)
        windowFocusCallbacks.removeValue(forKey: identifier)
        logger.debug("Removed callback: \(identifier)")
    }

    func registerHotkeys(_ bindings: [HotkeyBinding]) throws {
        logger.info("Registering \(bindings.count) bindings")

        guard bindings.count <= Self.registrationLimit else {
            throw HotkeyError.systemLimitReached
        }

        unregisterExistingHotkeys()

        for binding in bindings {
            do {
                try registerSingleHotkey(binding)
                logger.debug("Registered: '\(binding.windowTitle)'")
            } catch {
                logger.logError(
                    error,
                    context: "Registration failed: '\(binding.windowTitle)'")
                throw error
            }
        }
    }

    func initializeEventHandler() throws {
        logger.debug("Configuring event handler")

        let eventSpec = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
        ]

        var handlerRef: EventHandlerRef?
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                return service.processHotkeyEvent(event)
            },
            1,
            eventSpec,
            selfPtr,
            &handlerRef
        )

        if status != noErr {
            throw HotkeyError.eventHandlerFailed(status)
        }

        self.eventHandlerIdentifier = handlerRef
    }

    private func processHotkeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }

        var hotkeyID = EventHotKeyID()
        let result = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )

        if result == noErr {
            let currentEvent = HotkeyEventProcessor(id: hotkeyID.id, timestamp: Date())

            processingQueue.async { [weak self] in
                guard let self = self else { return }

                guard currentEvent.shouldProcess(after: self.previousEvent) else {
                    logger.debug("Debounced: \(hotkeyID.id)")
                    return
                }

                self.previousEvent = currentEvent

                if let (_, binding) = self.activeHotkeys[hotkeyID.id] {
                    logger.debug("Processing: '\(binding.windowTitle)'")

                    DispatchQueue.main.async { [weak self] in
                        self?.windowFocusCallbacks.values.forEach { $0(binding.windowTitle) }
                    }
                }
            }

            return noErr
        }

        logger.warning("Event processing failed: \(result)")
        return OSStatus(eventNotHandledErr)
    }

    private func registerSingleHotkey(_ binding: HotkeyBinding) throws {
        let modifiers = binding.modifiers.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else {
            throw HotkeyError.invalidModifiers
        }

        let hotkeyID = EventHotKeyID(signature: 0x4F56_5257, id: nextIdentifier)
        let carbonModifiers = CarbonModifierTranslator.convert(modifiers)

        var hotkeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(binding.keyCode),
            carbonModifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr, let hotkeyRef = hotkeyRef {
            activeHotkeys[nextIdentifier] = (hotkeyRef, binding)
            nextIdentifier += 1
            logger.debug("Registration successful: \(binding.hotkeyDisplayString)")
        } else {
            throw HotkeyError.registrationFailed(status)
        }
    }

    private func unregisterExistingHotkeys() {
        logger.debug("Removing existing registrations")
        activeHotkeys.values.forEach { registration in
            UnregisterEventHotKey(registration.0)
        }
        activeHotkeys.removeAll()
    }

    private func cleanupResources() {
        logger.debug("Cleaning up resources")
        unregisterExistingHotkeys()
        if let handler = eventHandlerIdentifier {
            RemoveEventHandler(handler)
        }
    }
}

struct HotkeyEventProcessor {
    let id: UInt32
    let timestamp: Date
    private static let minimumProcessingInterval: TimeInterval = 0.2

    func shouldProcess(after previousEvent: HotkeyEventProcessor?) -> Bool {
        guard let previous = previousEvent,
            id == previous.id
        else {
            return true
        }
        return timestamp.timeIntervalSince(previous.timestamp) > Self.minimumProcessingInterval
    }
}

enum HotkeyError: LocalizedError {
    case registrationFailed(OSStatus)
    case eventHandlerFailed(OSStatus)
    case invalidModifiers
    case systemLimitReached

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            return "Registration failed: \(status)"
        case .eventHandlerFailed(let status):
            return "Event handler failed: \(status)"
        case .invalidModifiers:
            return "Invalid modifier combination"
        case .systemLimitReached:
            return "Registration limit reached"
        }
    }
}

enum CarbonModifierTranslator {
    static func convert(_ nsModifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        if nsModifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if nsModifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if nsModifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if nsModifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        return carbonModifiers
    }
}
