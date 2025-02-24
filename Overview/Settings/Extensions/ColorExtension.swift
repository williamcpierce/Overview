/*
 Settings/Extensions/ColorExtension.swift
 Overview

 Created by William Pierce on 12/27/24.

 Provides color persistence capabilities for SwiftUI Color values.
*/

import SwiftUI

extension Color: @retroactive RawRepresentable {
    public init?(rawValue: String) {
        guard !rawValue.isEmpty else {
            self = .gray
            return
        }

        guard let data = Data(base64Encoded: rawValue) else {
            AppLogger.settings.warning("Failed to decode base64 color data")
            self = .gray
            return
        }

        do {
            guard
                let nsColor = try NSKeyedUnarchiver.unarchivedObject(
                    ofClass: NSColor.self, from: data)
            else {
                AppLogger.settings.warning("Failed to unarchive NSColor")
                self = .gray
                return
            }

            self.init(nsColor)
        } catch {
            AppLogger.settings.logError(error, context: "Failed to decode color from UserDefaults")
            self = .gray
        }
    }

    public var rawValue: String {
        let nsColor = NSColor(self)
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: nsColor,
                requiringSecureCoding: false
            )
            return data.base64EncodedString()
        } catch {
            AppLogger.settings.logError(error, context: "Failed to encode color for UserDefaults")
            return ""
        }
    }
}
