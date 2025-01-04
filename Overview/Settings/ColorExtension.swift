/*
 Settings/ColorExtension.swift
 Overview

 Created by William Pierce on 12/27/24.
*/

import SwiftUI

extension Color {
    /// Explicitly extracted Core Graphics color
    /// for the purpose of reconstruction and persistance.
    var cgColor_: CGColor {
        NSColor(self).cgColor
    }
}

extension UserDefaults {
    func setColor(_ color: Color, forKey key: String) {
        let cgColor: CGColor = color.cgColor_
        let array: [CGFloat] = cgColor.components ?? []
        set(array, forKey: key)
    }

    func color(forKey key: String) -> Color {
        guard let array = object(forKey: key) as? [CGFloat] else { return .accentColor }
        let color = CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: array)!
        return Color(color)
    }
}
