/*
 Hotkey/HotkeyService.swift
 Overview

 Created by William Pierce on 12/8/24

 Manages system-level hotkey registration and event processing,
 providing a centralized service for keyboard shortcut handling.
*/

import Carbon
import Cocoa
import SwiftUI

final class HotkeyService {
    // Constants
    private static let registrationLimit: Int = 50
    
    // Dependencies
    private let logger = AppLogger.hotkeys

    // Private State
    private var activeHotkeys: [UInt32: (EventHotKeyRef, HotkeyBinding)] = [:]
    private var eventHandlerIdentifier: EventHandlerRef?
    private var nextIdentifier: UInt32 = 1
    private var previousEvent: HotkeyEventProcessor?
    private var sourceFocusCallbacks: [ObjectIdentifier: (String) -> Void] = [:]
    private let processingQueue = DispatchQueue(label: "com.Overview.HotkeyEventQueue")
    
    // Singleton
    static let shared: HotkeyService = HotkeyService()

    deinit {
        cleanupResources()
    }

    // MARK: - Public Interface

    func registerCallback(owner: AnyObject, callback: @escaping (String) -> Void) {
        let identifier = ObjectIdentifier(owner)
        sourceFocusCallbacks[identifier] = callback
        logger.debug("Registered callback handler: \(identifier)")
    }

    func removeCallback(for owner: AnyObject) {
        let identifier = ObjectIdentifier(owner)
        sourceFocusCallbacks.removeValue(forKey: identifier)
        logger.debug("Removed callback handler: \(identifier)")
    }

    func registerHotkeys(_ bindings: [HotkeyBinding]) throws {
        logger.info("Processing hotkey registration: count=\(bindings.count)")

        guard bindings.count <= Self.registrationLimit else {
            throw HotkeyError.systemLimitReached
        }

        unregisterExistingHotkeys()

        for binding in bindings {
            do {
                try registerSingleHotkey(binding)
                logger.debug("Registered hotkey: '\(binding.sourceTitle)'")
            } catch {
                logger.logError(error, context: "Registration failed: '\(binding.sourceTitle)'")
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
        let selfPtr = UnsafeMutableRawPointer(
            Unmanaged.passUnretained(self).toOpaque())

        let status: OSStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            {
                (_: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?)
                    -> OSStatus in
                guard let userData: UnsafeMutableRawPointer = userData else {
                    return OSStatus(eventNotHandledErr)
                }
                let service: HotkeyService = Unmanaged<HotkeyService>.fromOpaque(userData)
                    .takeUnretainedValue()
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

    // MARK: - Event Processing

    private func processHotkeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event: EventRef = event else { return OSStatus(eventNotHandledErr) }

        var hotkeyID = EventHotKeyID()
        let result: OSStatus = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )

        if result == noErr {
            let currentEvent = HotkeyEventProcessor(
                id: hotkeyID.id, timestamp: Date())

            processingQueue.async { [weak self] in
                guard let self = self else { return }

                guard currentEvent.shouldProcess(after: self.previousEvent) else {
                    logger.debug("Debounced event: \(hotkeyID.id)")
                    return
                }

                self.previousEvent = currentEvent

                if let (_, binding) = self.activeHotkeys[hotkeyID.id] {
                    logger.debug("Processing event: '\(binding.sourceTitle)'")

                    DispatchQueue.main.async { [weak self] in
                        self?.sourceFocusCallbacks.values.forEach { $0(binding.sourceTitle) }
                    }
                }
            }

            return noErr
        }

        logger.warning("Event processing failed: \(result)")
        return OSStatus(eventNotHandledErr)
    }

    // MARK: - Registration Management

    private func registerSingleHotkey(_ binding: HotkeyBinding) throws {
        let modifiers: NSEvent.ModifierFlags = binding.modifiers.intersection([
            .command, .option, .control, .shift,
        ])
        guard !modifiers.isEmpty else {
            throw HotkeyError.invalidModifiers
        }

        let hotkeyID = EventHotKeyID(signature: 0x4F56_5257, id: nextIdentifier)
        let carbonModifiers: UInt32 = CarbonModifierTranslator.convert(modifiers)

        var hotkeyRef: EventHotKeyRef?
        let status: OSStatus = RegisterEventHotKey(
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
            logger.debug("Registration completed: \(binding.hotkeyDisplayString)")
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
        logger.debug("Cleaning up service resources")
        unregisterExistingHotkeys()
        if let handler: EventHandlerRef = eventHandlerIdentifier {
            RemoveEventHandler(handler)
        }
    }
}

// MARK: - Support Types

struct HotkeyEventProcessor {
    let id: UInt32
    let timestamp: Date
    private static let minimumProcessingInterval: TimeInterval = 0.2

    func shouldProcess(after previousEvent: HotkeyEventProcessor?) -> Bool {
        guard let previous: HotkeyEventProcessor = previousEvent,
            id == previous.id
        else {
            return true
        }
        return timestamp.timeIntervalSince(previous.timestamp) > Self.minimumProcessingInterval
    }
}

enum HotkeyError: LocalizedError {
    case eventHandlerFailed(OSStatus)
    case invalidModifiers
    case registrationFailed(OSStatus)
    case systemLimitReached

    var errorDescription: String? {
        switch self {
        case .eventHandlerFailed(let status):
            return "Event handler failed: \(status)"
        case .invalidModifiers:
            return "Invalid modifier combination"
        case .registrationFailed(let status):
            return "Registration failed: \(status)"
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
