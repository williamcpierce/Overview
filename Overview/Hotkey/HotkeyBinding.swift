/*
 Hotkey/HotkeyBinding.swift
 Overview

 Created by William Pierce on 12/8/24.

 Represents a configurable keyboard shortcut binding that maps
 specific key combinations to window management actions.
*/

import Carbon
import Cocoa

struct HotkeyBinding: Codable, Equatable, Hashable {
    let keyCode: Int
    let windowTitle: String
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
        var modifierSymbols: [String] = [String]()
        if modifiers.contains(.command) { modifierSymbols.append("⌘") }
        if modifiers.contains(.option) { modifierSymbols.append("⌥") }
        if modifiers.contains(.control) { modifierSymbols.append("⌃") }
        if modifiers.contains(.shift) { modifierSymbols.append("⇧") }

        let keySymbol: String = Self.translateKeyCodeToSymbol(keyCode) ?? "Key\(keyCode)"
        modifierSymbols.append(keySymbol)

        return modifierSymbols.joined()
    }

    /// Translates Carbon key codes to human-readable symbols using the current keyboard layout
    private static func translateKeyCodeToSymbol(_ keyCode: Int) -> String? {
        let specialKeys: [Int: String] = [
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]

        if let specialKey: String = specialKeys[keyCode] {
            return specialKey
        }

        guard
            let currentKeyboard: TISInputSource = TISCopyCurrentKeyboardLayoutInputSource()?
                .takeRetainedValue(),
            let layoutData: UnsafeMutableRawPointer = TISGetInputSourceProperty(
                currentKeyboard, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let keyboardLayout: Data =
            Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        var chars: [UniChar] = [UniChar](repeating: 0, count: 4)
        var stringLength: Int = 0
        var deadKeyState: UInt32 = 0

        let status: OSStatus = keyboardLayout.withUnsafeBytes { buffer in
            guard
                let layoutPtr: UnsafePointer<UCKeyboardLayout> = buffer.baseAddress?
                    .assumingMemoryBound(to: UCKeyboardLayout.self)
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
