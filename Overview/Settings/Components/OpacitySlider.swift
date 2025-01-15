/*
 Settings/Components/OpacitySlider.swift
 Overview

 Created by William Pierce on 1/9/25.
*/

import SwiftUI

struct OpacitySlider: NSViewRepresentable {
    @Binding var value: Double

    func makeNSView(context: Context) -> NSSlider {
        let slider: NSSlider = NSSlider(
            value: value,
            minValue: 0.05,
            maxValue: 1.0,
            target: context.coordinator,
            action: #selector(Coordinator.valueChanged(_:))
        )
        slider.isContinuous = true
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        nsView.doubleValue = value
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    class Coordinator: NSObject {
        var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc func valueChanged(_ sender: NSSlider) {
            value.wrappedValue = round(sender.doubleValue * 100) / 100
        }
    }
}
