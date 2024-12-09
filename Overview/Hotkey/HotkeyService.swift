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

/// Error types that can occur during hotkey operations
///
/// Key responsibilities:
/// - Provides specific error cases for hotkey registration failures
/// - Enables detailed error handling and reporting
/// - Maintains consistent error messaging
enum HotkeyError: Error {
    /// Carbon API registration failed with specific status code
    case registrationFailed(OSStatus)
    
    /// Event handler installation failed with specific status code
    case eventHandlerFailed(OSStatus)
    
    /// No valid modifier keys specified in binding
    case invalidModifiers
}

/// Manages registration and handling of global keyboard shortcuts for window focus
///
/// Key responsibilities:
/// - Maintains active hotkey registrations with Carbon APIs
/// - Processes keyboard events and triggers window focus
/// - Persists hotkey bindings across app launches
/// - Coordinates hotkey callback registration
///
/// Coordinates with:
/// - HotkeyBinding: Provides hotkey configuration data
/// - WindowManager: Executes window focus operations
/// - AppSettings: Stores persistent hotkey configurations
///
/// Context: Uses Carbon Event Manager APIs as they provide system-wide hotkey
/// functionality not available through AppKit or SwiftUI. This allows Overview
/// to respond to keyboard shortcuts even when not the active application.
final class HotkeyService {
    // MARK: - Properties

    /// Shared instance for app-wide hotkey management
    static let shared = HotkeyService()

    /// Maps hotkey IDs to their references and bindings
    /// - Note: Carbon API requires unique ID for each hotkey
    private var registeredHotkeys: [UInt32: (EventHotKeyRef, HotkeyBinding)] = [:]

    /// Counter for generating unique hotkey identifiers
    /// - Note: Increments with each registration
    private var nextHotkeyID: UInt32 = 1

    /// Maps object identifiers to their focus callbacks
    /// - Note: Weak references prevent retain cycles
    private var focusCallbacks: [ObjectIdentifier: (String) -> Void] = [:]

    /// Storage interface for persistent hotkey configuration
    private let storage: UserDefaults

    /// Storage key for hotkey binding persistence
    private let storageKey = "hotkeyBindings"

    // MARK: - Computed Properties

    /// Currently registered hotkey bindings
    /// - Note: Persisted across app launches
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

    /// Creates service instance and configures event handling
    /// - Parameter storage: UserDefaults instance for persistence
    /// - Note: Private to enforce singleton pattern
    private init(storage: UserDefaults = .standard) {
        AppLogger.hotkeys.debug("Initializing HotkeyService")
        self.storage = storage
        do {
            try setupEventHandler()
            AppLogger.hotkeys.info("HotkeyService initialized successfully")
        } catch {
            AppLogger.logError(error,
                             context: "Failed to initialize HotkeyService",
                             logger: AppLogger.hotkeys)
        }
    }

    // MARK: - Public Methods

    /// Registers a callback to be notified when hotkeys trigger window focus
    ///
    /// Flow:
    /// 1. Creates weak reference to callback owner
    /// 2. Stores callback for future invocation
    /// 3. Maintains object lifecycle safety
    ///
    /// - Parameters:
    ///   - owner: Object registering the callback
    ///   - callback: Focus handler to invoke
    func registerCallback(owner: AnyObject, callback: @escaping (String) -> Void) {
        let identifier = ObjectIdentifier(owner)
        focusCallbacks[identifier] = callback
        AppLogger.hotkeys.debug("Registered callback for owner: \(identifier)")
    }

    /// Removes callback registration for specified owner
    ///
    /// - Parameter owner: Object whose callback should be removed
    /// - Note: Safe to call multiple times for same owner
    func removeCallback(for owner: AnyObject) {
        let identifier = ObjectIdentifier(owner)
        focusCallbacks.removeValue(forKey: identifier)
        AppLogger.hotkeys.debug("Removed callback for owner: \(identifier)")
    }

    /// Updates registered hotkeys with new binding configuration
    ///
    /// Flow:
    /// 1. Unregisters all existing hotkeys
    /// 2. Registers new bindings
    /// 3. Updates persistent storage
    ///
    /// - Parameter bindings: New hotkey configuration
    /// - Warning: May throw if Carbon APIs fail during registration
    func registerHotkeys(_ bindings: [HotkeyBinding]) {
        AppLogger.hotkeys.info("Registering \(bindings.count) hotkey bindings")
        unregisterAllHotkeys()

        for binding in bindings {
            do {
                try register(binding)
                AppLogger.hotkeys.debug("Registered hotkey for '\(binding.windowTitle)'")
            } catch {
                AppLogger.logError(error,
                                 context: "Failed to register hotkey for '\(binding.windowTitle)'",
                                 logger: AppLogger.hotkeys)
            }
        }

        self.bindings = bindings
    }

    // MARK: - Private Methods

    /// Configures Carbon event handling for hotkey processing
    ///
    /// Flow:
    /// 1. Creates event specification
    /// 2. Sets up handler function
    /// 3. Installs event handler
    ///
    /// - Throws: HotkeyError if handler installation fails
    /// - Warning: Must be called during initialization
    private func setupEventHandler() throws {
        AppLogger.hotkeys.debug("Setting up Carbon event handler")
        
        let eventSpec = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
        ]

        // Context: selfPtr must be maintained by Carbon until handler is removed
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandlerCallback,
            1,
            eventSpec,
            selfPtr,
            nil
        )

        if status != noErr {
            throw HotkeyError.eventHandlerFailed(status)
        }
    }

    /// Carbon event handler callback
    /// - Note: Must be static to work with C API
    private let eventHandlerCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
        guard let userData = userData else { return OSStatus(eventNotHandledErr) }
        let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
        return service.handleHotkeyEvent(event)
    }

    /// Processes hotkey events and triggers focus callbacks
    ///
    /// Flow:
    /// 1. Extracts hotkey ID from event
    /// 2. Retrieves associated binding
    /// 3. Notifies callbacks with window title
    ///
    /// - Parameter event: Carbon event containing hotkey data
    /// - Returns: Event handling status code
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

        if result == noErr, let (_, binding) = registeredHotkeys[hotkeyID.id] {
            AppLogger.hotkeys.debug("Hotkey pressed for window: '\(binding.windowTitle)'")
            
            // Context: Small delay prevents focus race conditions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.focusCallbacks.values.forEach { $0(binding.windowTitle) }
            }
            return noErr
        }

        AppLogger.hotkeys.warning("Failed to handle hotkey event: \(result)")
        return OSStatus(eventNotHandledErr)
    }

    /// Registers a single hotkey binding with the system
    ///
    /// Flow:
    /// 1. Validates modifier flags
    /// 2. Creates unique hotkey ID
    /// 3. Registers with Carbon API
    /// 4. Stores registration if successful
    ///
    /// - Parameter binding: Hotkey configuration to register
    /// - Throws: HotkeyError if registration fails
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
            AppLogger.hotkeys.debug("Successfully registered hotkey: \(binding.hotkeyDisplayString)")
        } else {
            throw HotkeyError.registrationFailed(status)
        }
    }

    /// Unregisters all active hotkeys from the system
    ///
    /// Flow:
    /// 1. Removes each registration from Carbon
    /// 2. Clears internal registration storage
    ///
    /// - Warning: Must be called before updating registrations
    private func unregisterAllHotkeys() {
        AppLogger.hotkeys.info("Unregistering all hotkeys")
        registeredHotkeys.values.forEach { registration in
            UnregisterEventHotKey(registration.0)
        }
        registeredHotkeys.removeAll()
    }

    /// Cleanup registered hotkeys on deallocation
    /// - Warning: Required to prevent system hotkey leaks
    deinit {
        AppLogger.hotkeys.debug("HotkeyService deinitializing")
        unregisterAllHotkeys()
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
