/*
 HotkeyService.swift
 Overview
 
 Created by William Pierce on 12/8/24.
 
 Manages global hotkey registration and handling for window focus shortcuts.
*/

import Carbon
import Cocoa
import OSLog

/// Manages registration and handling of global keyboard shortcuts
class HotkeyService {
    // MARK: - Singleton
    
    /// Shared instance for the entire application
    static let shared = HotkeyService()
    
    // MARK: - Properties
    
    /// Currently registered hotkeys mapping ID to (reference, binding) tuple
    private var registeredHotkeys: [UInt32: (EventHotKeyRef, HotkeyBinding)] = [:]
    
    /// Next available hotkey ID
    private var nextHotkeyID: UInt32 = 1
    
    /// Logger for debugging hotkey issues
    private let logger = Logger(subsystem: "com.Overview.HotkeyService", category: "Hotkeys")
    
    /// Callback registry for window focus actions, keyed by object identifier
    private var focusCallbacks: [ObjectIdentifier: (String) -> Void] = [:]
    
    // MARK: - Initialization
    
    private init() {
        setupEventHandler()
        logger.info("HotkeyService singleton initialized")
    }
    
    deinit {
        unregisterAllHotkeys()
        logger.info("HotkeyService singleton deinitialized")
    }
    
    // MARK: - Public Methods
    
    /// Registers a callback for window focus events
    /// - Parameters:
    ///   - owner: The object registering the callback (used for tracking)
    ///   - callback: The callback to be executed when a hotkey is pressed
    func registerFocusCallback(owner: AnyObject, callback: @escaping (String) -> Void) {
        let identifier = ObjectIdentifier(owner)
        if focusCallbacks[identifier] == nil {
            focusCallbacks[identifier] = callback
            logger.debug("New focus callback registered for \(String(describing: type(of: owner))). Total callbacks: \(self.focusCallbacks.count)")
        } else {
            logger.debug("Focus callback already registered for \(String(describing: type(of: owner)))")
        }
    }
    
    /// Removes callback for specific owner
    func removeFocusCallback(for owner: AnyObject) {
        let identifier = ObjectIdentifier(owner)
        if focusCallbacks.removeValue(forKey: identifier) != nil {
            logger.debug("Removed focus callback for \(String(describing: type(of: owner))). Remaining callbacks: \(self.focusCallbacks.count)")
        }
    }
    
    /// Removes all registered callbacks
    func clearCallbacks() {
        focusCallbacks.removeAll()
        logger.debug("All focus callbacks cleared")
    }
    
    /// Registers hotkeys from current settings
    func registerHotkeys(_ bindings: [HotkeyBinding]) {
        logger.info("Registering \(bindings.count) hotkeys")
        
        // Compare with existing bindings to avoid unnecessary re-registration
        let existingBindings = Set(registeredHotkeys.values.map { $0.1 })
        let newBindings = Set(bindings)
        
        if existingBindings == newBindings {
            logger.info("Hotkeys already registered with same bindings")
            return
        }
        
        // First unregister all existing hotkeys
        unregisterAllHotkeys()
        
        // Register new bindings
        for binding in bindings {
            register(binding)
        }
        
        logger.info("Currently registered hotkeys: \(self.registeredHotkeys.count)")
        for (id, (_, binding)) in self.registeredHotkeys {
            logger.debug("Registered hotkey ID \(id): \(binding.hotkeyDisplayString) for window '\(binding.windowTitle)'")
        }
    }
    
    // MARK: - Private Methods
    
    /// Sets up global event handler for hotkeys
    private func setupEventHandler() {
        let eventSpec = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
        ]
        
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else {
                    return OSStatus(eventNotHandledErr)
                }
                let this = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                return this.handleHotkeyEvent(event)
            },
            1,
            eventSpec,
            selfPtr,
            nil
        )
        
        if status == noErr {
            logger.info("Event handler installed successfully")
        } else {
            logger.error("Failed to install event handler: \(status)")
        }
    }
    
    /// Processes hotkey events and triggers focus callbacks
    private func handleHotkeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else {
            logger.error("Received nil event")
            return OSStatus(eventNotHandledErr)
        }
        
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
            if let (_, binding) = self.registeredHotkeys[hotkeyID.id] {
                logger.info("Hotkey pressed: ID \(hotkeyID.id), window '\(binding.windowTitle)'")
                
                // Add a small delay and dispatch to main queue to improve cross-app activation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.focusCallbacks.values.forEach { callback in
                        callback(binding.windowTitle)
                    }
                }
                return noErr
            } else {
                logger.error("Received event for unknown hotkey ID: \(hotkeyID.id)")
            }
        } else {
            logger.error("Failed to get event parameter: \(result)")
        }
        
        return OSStatus(eventNotHandledErr)
    }
    
    /// Registers a single hotkey binding
    private func register(_ binding: HotkeyBinding) {
        // Require at least one modifier key
        let modifiers = binding.modifiers.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else {
            logger.warning("Skipping registration for '\(binding.windowTitle)': No modifier keys")
            return
        }
        
        let hotkeyID = EventHotKeyID(
            signature: 0x4F565257, // 'OVRW'
            id: self.nextHotkeyID
        )
        
        let carbonModifiers = carbonModifiersFromNSEvent(modifiers)
        logger.debug("Registering hotkey for '\(binding.windowTitle)': key \(binding.keyCode), modifiers \(String(format: "0x%x", carbonModifiers))")
        
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
            self.registeredHotkeys[self.nextHotkeyID] = (hotkeyRef, binding)
            logger.info("Successfully registered hotkey ID \(self.nextHotkeyID) for '\(binding.windowTitle)'")
            self.nextHotkeyID += 1
        } else {
            logger.error("Failed to register hotkey for '\(binding.windowTitle)': \(status)")
        }
    }
    
    /// Converts NSEvent modifier flags to Carbon modifier flags
    private func carbonModifiersFromNSEvent(_ nsModifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        
        if nsModifiers.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if nsModifiers.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if nsModifiers.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        if nsModifiers.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        
        return carbonModifiers
    }
    
    /// Unregisters all active hotkeys
    private func unregisterAllHotkeys() {
        logger.info("Unregistering \(self.registeredHotkeys.count) hotkeys")
        
        for (id, (hotkeyRef, binding)) in self.registeredHotkeys {
            let status = UnregisterEventHotKey(hotkeyRef)
            if status == noErr {
                logger.debug("Successfully unregistered hotkey ID \(id) for '\(binding.windowTitle)'")
            } else {
                logger.error("Failed to unregister hotkey ID \(id): \(status)")
            }
        }
        registeredHotkeys.removeAll()
    }
}

// MARK: - HotkeyBinding Extensions

extension HotkeyBinding {
    /// Returns a human-readable string representation of the hotkey
    var hotkeyDisplayString: String {
        var parts: [String] = []
        
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        
        if let keyChar = keyCodeToString(keyCode) {
            parts.append(keyChar)
        } else {
            parts.append("Key\(keyCode)")
        }
        
        return parts.joined(separator: "")
    }
    
    private func keyCodeToString(_ keyCode: Int) -> String? {
        let keyCodeMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 32: "U", 34: "I", 31: "O", 35: "P",
            37: "L", 38: "J", 39: "K", 40: "'", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "5", 23: "6", 24: "7",
            25: "8", 26: "9", 27: "0"
        ]
        
        return keyCodeMap[keyCode]
    }
}
