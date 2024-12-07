/*
 SettingsView.swift
 Overview

 Created by William Pierce on 10/13/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appSettings: AppSettings
    
    var body: some View {
        TabView {
            GeneralSettingsView(appSettings: appSettings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                
            WindowSettingsView(appSettings: appSettings)
                .tabItem {
                    Label("Windows", systemImage: "macwindow")
                }
                
            PerformanceSettingsView(appSettings: appSettings)
                .tabItem {
                    Label("Performance", systemImage: "gauge.medium")
                }
        }
        .frame(width: 340, height: 220)
    }
}

struct SliderRepresentable: NSViewRepresentable {
    @Binding var value: Double
    let minValue: Double
    let maxValue: Double
    
    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value, minValue: minValue, maxValue: maxValue, target: context.coordinator, action: #selector(Coordinator.valueChanged(_:)))
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
            let rounded = round(sender.doubleValue * 100) / 100
            value.wrappedValue = rounded
        }
    }
}

// Preview provider for SwiftUI canvas
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appSettings: AppSettings())
    }
}
