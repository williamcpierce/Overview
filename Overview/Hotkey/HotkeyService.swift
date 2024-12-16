/*
 HotkeyService.swift
 Overview

 Created by William Pierce on 12/8/24.

 Manages system-wide keyboard shortcuts using Carbon Event Manager APIs, providing
 centralized registration and handling of global hotkeys for window focus operations.
 Core component of Overview's window management system.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import Carbon
import Cocoa

/// Represents a hotkey event for processing
private struct HotkeyEvent {
    let id: UInt32
    let timestamp: Date

    // Minimum time between identical events to prevent duplicates
    static let debounceInterval: TimeInterval = 0.2

    func shouldProcess(previous: HotkeyEvent?) -> Bool {
        guard let previous = previous,
            id == previous.id
        else {
            return true
        }
        return timestamp.timeIntervalSince(previous.timestamp) > Self.debounceInterval
    }
}

final class HotkeyService {
    // MARK: - Properties

    static let shared = HotkeyService()
    private var registeredHotkeys: [UInt32: (EventHotKeyRef, HotkeyBinding)] = [:]
    private var nextHotkeyID: UInt32 = 1
    private var focusCallbacks: [ObjectIdentifier: (String) -> Void] = [:]
    private let storage: UserDefaults
    private let storageKey = "hotkeyBindings"

    // Event handling properties
    private let eventQueue = DispatchQueue(label: "com.Overview.HotkeyEventQueue")
    private var lastProcessedEvent: HotkeyEvent?
    private var eventHandlerRef: EventHandlerRef?

    // Maximum number of allowed hotkey registrations
    private let maxHotkeyRegistrations = 50

    // MARK: - Computed Properties

    var bindings: [HotkeyBinding] {
        get {
            guard let data = storage.data(forKey: storageKey),
                let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data)
            else {
                AppLogger.hotkeys.debug("No stored bindings found")
                return []
            }
            AppLogger.hotkeys.debug("Loaded \(decoded.count) stored bindings")
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                storage.set(encoded, forKey: storageKey)
                AppLogger.hotkeys.info("Saved \(newValue.count) bindings to storage")
            } else {
                AppLogger.hotkeys.error("Failed to encode hotkey bindings")
            }
        }
    }

    // MARK: - Initialization

    private init(storage: UserDefaults = .standard) {
        AppLogger.hotkeys.debug("Initializing HotkeyService")
        self.storage = storage
        do {
            try setupEventHandler()
            AppLogger.hotkeys.info("HotkeyService initialized successfully")
        } catch {
            AppLogger.logError(
                error,
                context: "Failed to initialize HotkeyService",
                logger: AppLogger.hotkeys)
        }
    }

    deinit {
        cleanup()
    }

    // MARK: - Public Methods

    func registerCallback(owner: AnyObject, callback: @escaping (String) -> Void) {
        let identifier = ObjectIdentifier(owner)
        focusCallbacks[identifier] = callback
        AppLogger.hotkeys.debug("Registered callback for owner: \(identifier)")
    }

    func removeCallback(for owner: AnyObject) {
        let identifier = ObjectIdentifier(owner)
        focusCallbacks.removeValue(forKey: identifier)
        AppLogger.hotkeys.debug("Removed callback for owner: \(identifier)")
    }

    func registerHotkeys(_ bindings: [HotkeyBinding]) throws {
        AppLogger.hotkeys.info("Registering \(bindings.count) hotkey bindings")

        // Validate registration limit
        guard bindings.count <= maxHotkeyRegistrations else {
            throw HotkeyError.systemLimitReached
        }

        unregisterAllHotkeys()

        for binding in bindings {
            do {
                try register(binding)
                AppLogger.hotkeys.debug("Registered hotkey for '\(binding.windowTitle)'")
            } catch {
                AppLogger.logError(
                    error,
                    context: "Failed to register hotkey for '\(binding.windowTitle)'",
                    logger: AppLogger.hotkeys)
                throw error
            }
        }

        self.bindings = bindings
    }

    // MARK: - Private Methods

    private func setupEventHandler() throws {
        AppLogger.hotkeys.debug("Setting up Carbon event handler")

        let eventSpec = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
        ]

        // Create event handler
        var handlerRef: EventHandlerRef?
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                return service.handleHotkeyEvent(event)
            },
            1,
            eventSpec,
            selfPtr,
            &handlerRef
        )

        if status != noErr {
            throw HotkeyError.eventHandlerFailed(status)
        }

        self.eventHandlerRef = handlerRef
    }

    private func handleHotkeyEvent(_ event: EventRef?) -> OSStatus {
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
            let currentEvent = HotkeyEvent(id: hotkeyID.id, timestamp: Date())

            eventQueue.async { [weak self] in
                guard let self = self else { return }

                // Check if we should process this event
                guard currentEvent.shouldProcess(previous: self.lastProcessedEvent) else {
                    AppLogger.hotkeys.debug("Skipping debounced event: \(hotkeyID.id)")
                    return
                }

                self.lastProcessedEvent = currentEvent

                if let (_, binding) = self.registeredHotkeys[hotkeyID.id] {
                    AppLogger.hotkeys.debug(
                        "Processing hotkey event for window: '\(binding.windowTitle)'")

                    DispatchQueue.main.async { [weak self] in
                        self?.focusCallbacks.values.forEach { $0(binding.windowTitle) }
                    }
                }
            }

            return noErr
        }

        AppLogger.hotkeys.warning("Failed to handle hotkey event: \(result)")
        return OSStatus(eventNotHandledErr)
    }

    private func register(_ binding: HotkeyBinding) throws {
        let modifiers = binding.modifiers.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else {
            throw HotkeyError.invalidModifiers
        }

        let hotkeyID = EventHotKeyID(signature: 0x4F56_5257, id: nextHotkeyID)
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
            registeredHotkeys[nextHotkeyID] = (hotkeyRef, binding)
            nextHotkeyID += 1
            AppLogger.hotkeys.debug(
                "Successfully registered hotkey: \(binding.hotkeyDisplayString)")
        } else {
            throw HotkeyError.registrationFailed(status)
        }
    }

    private func unregisterAllHotkeys() {
        AppLogger.hotkeys.info("Unregistering all hotkeys")
        registeredHotkeys.values.forEach { registration in
            UnregisterEventHotKey(registration.0)
        }
        registeredHotkeys.removeAll()
    }

    private func cleanup() {
        AppLogger.hotkeys.debug("Cleaning up HotkeyService")

        // Remove all hotkey registrations
        unregisterAllHotkeys()

        // Remove event handler
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}

// MARK: - Error Types

enum HotkeyError: LocalizedError {
    case registrationFailed(OSStatus)
    case eventHandlerFailed(OSStatus)
    case invalidModifiers
    case systemLimitReached

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            return "Failed to register hotkey: \(status)"
        case .eventHandlerFailed(let status):
            return "Failed to install event handler: \(status)"
        case .invalidModifiers:
            return "Invalid modifier key combination"
        case .systemLimitReached:
            return "Maximum number of hotkeys reached"
        }
    }
}

// MARK: - Carbon Modifier Translation

/// Handles conversion between AppKit and Carbon modifier flags
/// - Note: Separated for clarity and potential reuse
private enum CarbonModifierTranslator {
    /// Converts NSEvent modifier flags to Carbon modifier mask
    /// - Parameter nsModifiers: NSEvent modifier flags to convert
    /// - Returns: Carbon API compatible modifier mask
    static func convert(_ nsModifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        if nsModifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if nsModifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if nsModifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if nsModifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        return carbonModifiers
    }
}
