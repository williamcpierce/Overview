/*
 HotkeyService.swift
 Overview

 Created by William Pierce on 12/8/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import Carbon
import Cocoa
import OSLog

final class HotkeyService {
    static let shared = HotkeyService()

    private var registeredHotkeys: [UInt32: (EventHotKeyRef, HotkeyBinding)] = [:]
    private var nextAvailableHotkeyID: UInt32 = 1
    private var windowFocusCallbacks: [ObjectIdentifier: (String) -> Void] = [:]
    private let storage: UserDefaults
    private let storageKey = "hotkeyBindings"

    var hotkeyBindings: [HotkeyBinding] {
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

    private init(storage: UserDefaults = .standard) {
        self.storage = storage
        do {
            try setupEventHandler()
        } catch {
        }
    }

    func registerCallback(owner: AnyObject, callback: @escaping (String) -> Void) {
        windowFocusCallbacks[ObjectIdentifier(owner)] = callback
    }

    func removeCallback(for owner: AnyObject) {
        windowFocusCallbacks.removeValue(forKey: ObjectIdentifier(owner))
    }

    func registerHotkeys(_ hotkeyBindings: [HotkeyBinding]) {
        unregisterAllHotkeys()

        for binding in hotkeyBindings {
            do {
                try register(binding)
            } catch {

            }
        }

        self.hotkeyBindings = hotkeyBindings
    }

    private func setupEventHandler() throws {
        let eventSpec = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
        ]

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

    private let eventHandlerCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
        guard let userData = userData else { return OSStatus(eventNotHandledErr) }
        let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
        return service.handleHotkeyEvent(event)
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
                self?.windowFocusCallbacks.values.forEach { $0(binding.windowTitle) }
            }
            return noErr
        }

        return OSStatus(eventNotHandledErr)
    }

    private func register(_ binding: HotkeyBinding) throws {
        let modifiers = binding.modifiers.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else {
            throw HotkeyError.invalidModifiers
        }

        let hotkeyID = EventHotKeyID(signature: 0x4F56_5257, id: nextAvailableHotkeyID)
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
            registeredHotkeys[nextAvailableHotkeyID] = (hotkeyRef, binding)
            nextAvailableHotkeyID += 1
        } else {
            throw HotkeyError.registrationFailed(status)
        }
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

private enum CarbonModifierTranslator {
    static func convert(_ nsModifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        if nsModifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if nsModifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if nsModifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if nsModifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        return carbonModifiers
    }
}

enum HotkeyError: Error {
    case registrationFailed(OSStatus)
    case eventHandlerFailed(OSStatus)
    case invalidModifiers
}
