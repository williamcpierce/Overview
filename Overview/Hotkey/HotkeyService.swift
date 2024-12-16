/*
 HotkeyService.swift
 Overview

 Created by William Pierce on 12/8/24

 Manages system-wide keyboard shortcuts using Carbon Event Manager APIs, providing a
 reliable and efficient implementation of global keyboard shortcuts. Primary coordinator
 for mapping keyboard combinations to window focus operations.
*/

import Carbon
import Cocoa

/// Processes and validates hotkey event handling with debouncing
///
/// Key responsibilities:
/// - Tracks event timing for debounce logic
/// - Validates event processing requirements
/// - Prevents duplicate event handling
private struct HotkeyEvent {
    let id: UInt32
    let timestamp: Date

    // Minimum time between identical events to prevent duplicates
    static let debounceInterval: TimeInterval = 0.2

    /// Determines if event should be processed based on timing
    ///
    /// Flow:
    /// 1. Checks for previous event match
    /// 2. Validates time interval requirements
    /// 3. Applies debounce logic
    ///
    /// - Parameter previous: Last processed event for comparison
    /// - Returns: Whether event should be processed
    func shouldProcess(previous: HotkeyEvent?) -> Bool {
        guard let previous = previous,
            id == previous.id
        else {
            return true
        }
        return timestamp.timeIntervalSince(previous.timestamp) > Self.debounceInterval
    }
}

/// Manages global keyboard shortcut registration and event handling for window focus operations
///
/// Key responsibilities:
/// - Registers and maintains system-wide keyboard shortcuts
/// - Maps keyboard combinations to window focus actions
/// - Handles event debouncing and validation
/// - Maintains shortcut persistence in UserDefaults
///
/// Coordinates with:
/// - HotkeyManager: Primary consumer of hotkey events
/// - WindowManager: Window focus target operations
/// - AppSettings: Hotkey configuration storage
/// - Carbon Event System: Low-level event handling
final class HotkeyService {
    // MARK: - Properties

    /// Shared instance for app-wide hotkey management
    static let shared = HotkeyService()

    /// Maps hotkey IDs to registration data and window bindings
    /// - Note: Used for O(1) event routing
    private var registeredHotkeys: [UInt32: (EventHotKeyRef, HotkeyBinding)] = [:]

    /// Next available unique identifier for hotkey registration
    private var nextHotkeyID: UInt32 = 1

    /// Registered callbacks for hotkey event handling
    /// - Note: Mapped by object identity to prevent retain cycles
    private var focusCallbacks: [ObjectIdentifier: (String) -> Void] = [:]

    /// Storage for persisting hotkey configurations
    private let storage: UserDefaults

    /// Key for storing hotkey bindings in UserDefaults
    private let storageKey = "hotkeyBindings"

    // Event handling properties
    /// Queue for processing hotkey events safely
    private let eventQueue = DispatchQueue(label: "com.Overview.HotkeyEventQueue")

    /// Most recently processed event for debounce logic
    private var lastProcessedEvent: HotkeyEvent?

    /// Reference to installed Carbon event handler
    /// - Note: Must be retained for handler lifetime
    private var eventHandlerRef: EventHandlerRef?

    /// Maximum allowed concurrent hotkey registrations
    /// - Note: Prevents system resource exhaustion
    private let maxHotkeyRegistrations = 50

    // MARK: - Computed Properties

    /// Current hotkey bindings with persistent storage
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

    /// Creates hotkey service with specified storage
    ///
    /// Flow:
    /// 1. Initializes storage reference
    /// 2. Configures event handler
    /// 3. Validates handler installation
    ///
    /// - Parameter storage: UserDefaults instance for persistence
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

    /// Registers callback for handling hotkey events
    ///
    /// Flow:
    /// 1. Creates unique identifier for owner
    /// 2. Stores callback reference
    /// 3. Maintains weak reference to prevent cycles
    ///
    /// - Parameters:
    ///   - owner: Object registering the callback
    ///   - callback: Handler for window focus requests
    func registerCallback(owner: AnyObject, callback: @escaping (String) -> Void) {
        let identifier = ObjectIdentifier(owner)
        focusCallbacks[identifier] = callback
        AppLogger.hotkeys.debug("Registered callback for owner: \(identifier)")
    }

    /// Removes callback registration for specified owner
    ///
    /// Flow:
    /// 1. Retrieves owner's identifier
    /// 2. Removes stored callback
    /// 3. Logs removal completion
    ///
    /// - Parameter owner: Object that registered callback
    func removeCallback(for owner: AnyObject) {
        let identifier = ObjectIdentifier(owner)
        focusCallbacks.removeValue(forKey: identifier)
        AppLogger.hotkeys.debug("Removed callback for owner: \(identifier)")
    }

    /// Registers collection of hotkey bindings with the system
    ///
    /// Flow:
    /// 1. Validates registration count limits
    /// 2. Removes existing registrations
    /// 3. Registers new bindings
    /// 4. Updates persistent storage
    ///
    /// - Parameter bindings: Array of hotkey configurations
    /// - Throws: HotkeyError for registration failures
    /// - Important: Previous registrations are removed before new ones are added
    func registerHotkeys(_ bindings: [HotkeyBinding]) throws {
        AppLogger.hotkeys.info("Registering \(bindings.count) hotkey bindings")

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

    /// Configures Carbon event handler for hotkey events
    ///
    /// Flow:
    /// 1. Creates event type specification
    /// 2. Installs system event handler
    /// 3. Stores handler reference
    ///
    /// - Throws: HotkeyError if handler installation fails
    /// - Important: Handler must be removed in cleanup
    private func setupEventHandler() throws {
        AppLogger.hotkeys.debug("Setting up Carbon event handler")

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

    /// Processes incoming hotkey events from Carbon
    ///
    /// Flow:
    /// 1. Extracts hotkey identifier from event
    /// 2. Validates event through debounce logic
    /// 3. Dispatches to registered callbacks
    ///
    /// - Parameter event: Carbon event reference
    /// - Returns: Status code indicating handling result
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

    /// Registers single hotkey binding with Carbon
    ///
    /// Flow:
    /// 1. Validates modifier requirements
    /// 2. Creates unique registration ID
    /// 3. Registers with Carbon API
    /// 4. Stores successful registration
    ///
    /// - Parameter binding: Configuration to register
    /// - Throws: HotkeyError for invalid configurations
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

    /// Removes all current hotkey registrations
    ///
    /// Flow:
    /// 1. Iterates through registered hotkeys
    /// 2. Unregisters each with Carbon
    /// 3. Clears registration storage
    private func unregisterAllHotkeys() {
        AppLogger.hotkeys.info("Unregistering all hotkeys")
        registeredHotkeys.values.forEach { registration in
            UnregisterEventHotKey(registration.0)
        }
        registeredHotkeys.removeAll()
    }

    /// Performs service cleanup before deallocation
    ///
    /// Flow:
    /// 1. Removes hotkey registrations
    /// 2. Removes event handler
    /// 3. Cleans up resources
    private func cleanup() {
        AppLogger.hotkeys.debug("Cleaning up HotkeyService")

        unregisterAllHotkeys()

        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during hotkey operations
enum HotkeyError: LocalizedError {
    /// Registration with Carbon API failed
    case registrationFailed(OSStatus)

    /// Event handler installation failed
    case eventHandlerFailed(OSStatus)

    /// No modifier keys specified in binding
    case invalidModifiers

    /// Too many concurrent registrations
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

/// Converts between AppKit and Carbon modifier flag representations
///
/// Key responsibilities:
/// - Translates NSEvent modifiers to Carbon format
/// - Maintains consistent modifier mapping
/// - Provides type-safe conversion interface
private enum CarbonModifierTranslator {
    /// Converts AppKit modifier flags to Carbon modifier mask
    ///
    /// Flow:
    /// 1. Extracts supported modifiers
    /// 2. Maps to Carbon constants
    /// 3. Combines into final mask
    ///
    /// - Parameter nsModifiers: AppKit modifier flags
    /// - Returns: Carbon-compatible modifier mask
    static func convert(_ nsModifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        if nsModifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if nsModifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if nsModifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if nsModifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        return carbonModifiers
    }
}
