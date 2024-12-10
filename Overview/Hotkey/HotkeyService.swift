/*
 HotkeyService.swift
 Overview
 
 Created by William Pierce on 12/8/24.
 
 Manages global hotkey registration and handling for window focus shortcuts.
*/

import Carbon
import Cocoa
import OSLog

final class HotkeyService {
    static let shared = HotkeyService()
    private var registeredHotkeys: [UInt32: (EventHotKeyRef, HotkeyBinding)] = [:]
    private var nextHotkeyID: UInt32 = 1
    private var focusCallbacks: [ObjectIdentifier: (String) -> Void] = [:]
    private let logger = Logger(subsystem: "com.Overview.HotkeyService", category: "Hotkeys")
    private let storage = UserDefaults.standard
    private let storageKey = "hotkeyBindings"
    
    var bindings: [HotkeyBinding] {
        get {
            guard let data = storage.data(forKey: storageKey),
                  let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                storage.set(encoded, forKey: storageKey)
            }
        }
    }
    
    private init() {
        setupEventHandler()
    }
    
    func registerCallback(owner: AnyObject, callback: @escaping (String) -> Void) {
        focusCallbacks[ObjectIdentifier(owner)] = callback
    }
    
    func removeCallback(for owner: AnyObject) {
        focusCallbacks.removeValue(forKey: ObjectIdentifier(owner))
    }
    
    func registerHotkeys(_ bindings: [HotkeyBinding]) {
        unregisterAllHotkeys()
        bindings.forEach(register)
        self.bindings = bindings
    }
    
    private func setupEventHandler() {
        let eventSpec = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))]
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
            nil
        )
        
        if status != noErr {
            logger.error("Failed to install event handler: \(status)")
        }
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
        
        if result == noErr, let (_, binding) = registeredHotkeys[hotkeyID.id] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.focusCallbacks.values.forEach { $0(binding.windowTitle) }
            }
            return noErr
        }
        
        return OSStatus(eventNotHandledErr)
    }
    
    private func register(_ binding: HotkeyBinding) {
        let modifiers = binding.modifiers.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else { return }
        
        let hotkeyID = EventHotKeyID(signature: 0x4F565257, id: nextHotkeyID)
        let carbonModifiers = carbonModifiersFromNSEvent(modifiers)
        
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
        }
    }
    
    private func carbonModifiersFromNSEvent(_ nsModifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        if nsModifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if nsModifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if nsModifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if nsModifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        return carbonModifiers
    }
    
    private func unregisterAllHotkeys() {
        registeredHotkeys.values.forEach { registration in
            UnregisterEventHotKey(registration.0)
        }
        registeredHotkeys.removeAll()
    }
    
    deinit {
        unregisterAllHotkeys()
    }
}
