/*
 Hotkey/HotkeyBinding.swift
 Overview

 Created by William Pierce on 12/8/24.
*/

import Carbon
import Cocoa

struct HotkeyBinding: Codable, Equatable, Hashable {
    let windowTitle: String
    let keyCode: Int
    private let modifierFlags: UInt

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags)
    }

    init(windowTitle: String, keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        self.windowTitle = windowTitle
        self.keyCode = keyCode
        self.modifierFlags = modifiers.intersection([.command, .option, .control, .shift]).rawValue
    }

    var hotkeyDisplayString: String {
        var modifierSymbols = [String]()
        if modifiers.contains(.command) { modifierSymbols.append("⌘") }
        if modifiers.contains(.option) { modifierSymbols.append("⌥") }
        if modifiers.contains(.control) { modifierSymbols.append("⌃") }
        if modifiers.contains(.shift) { modifierSymbols.append("⇧") }

        let keySymbol = Self.translateKeyCodeToSymbol(keyCode) ?? "Key\(keyCode)"
        modifierSymbols.append(keySymbol)

        return modifierSymbols.joined()
    }

    /// Translates Carbon key codes to human-readable symbols using the current keyboard layout
    private static func translateKeyCodeToSymbol(_ keyCode: Int) -> String? {
        let specialKeys: [Int: String] = [
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]

        if let specialKey = specialKeys[keyCode] {
            return specialKey
        }

        guard let currentKeyboard = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutData = TISGetInputSourceProperty(
                currentKeyboard, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let keyboardLayout = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        var chars = [UniChar](repeating: 0, count: 4)
        var stringLength = 0
        var deadKeyState: UInt32 = 0

        let status = keyboardLayout.withUnsafeBytes { buffer in
            guard let layoutPtr = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self)
            else { return errSecInvalidKeychain }

            return UCKeyTranslate(
                layoutPtr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &stringLength,
                &chars
            )
        }

        guard status == noErr else { return nil }
        return String(utf16CodeUnits: chars, count: stringLength).uppercased()
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
