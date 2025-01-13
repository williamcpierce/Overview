/*
 Settings/ColorExtension.swift
 Overview

 Created by William Pierce on 12/27/24.

 Provides color persistence capabilities for SwiftUI Color values.
*/

import SwiftUI

extension Color: @retroactive RawRepresentable {
    public init?(rawValue: String) {
        guard let data = Data(base64Encoded: rawValue),
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        else {
            self = .gray  // Fallback color
            return
        }
        
        self.init(nsColor)
    }

    public var rawValue: String {
        let nsColor = NSColor(self)
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false)
            return data.base64EncodedString()
        } catch {
            return ""
        }
    }
}

// Keep legacy UserDefaults support if needed
extension UserDefaults {
    func setColor(_ color: Color, forKey key: String) {
        set(color.rawValue, forKey: key)
    }

    func color(forKey key: String) -> Color {
        guard let rawValue = string(forKey: key),
              let color = Color(rawValue: rawValue) else {
            return .accentColor
        }
        return color
    }
}
