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
    private let frameRateOptions = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]
    
    var body: some View {
        TabView {
            // General Tab
            Form {
                Section {
                    Text("Overlays")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Toggle("Show focused window border", isOn: $appSettings.showFocusedBorder)
                    Toggle("Show window title", isOn: $appSettings.showWindowTitle)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gear") }
            
            // Window Tab
            Form {
                Section {
                    Text("Opacity")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 8) {
                        SliderRepresentable(
                            value: $appSettings.opacity,
                            minValue: 0.05,
                            maxValue: 1.0
                        )
                        Text("\(Int(appSettings.opacity * 100))%")
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }
                }
                
                Section {
                    Text("Default Size")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    ForEach([
                        ("Width", $appSettings.defaultWindowWidth),
                        ("Height", $appSettings.defaultWindowHeight)
                    ], id: \.0) { label, binding in
                        HStack {
                            Text("\(label):")
                            Spacer()
                            TextField("", value: binding, formatter: NumberFormatter())
                                .frame(width: 120)
                                .textFieldStyle(.roundedBorder)
                            Text("px")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Windows", systemImage: "macwindow") }
            
            // Performance Tab
            Form {
                Section {
                    Text("Frame Rate")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Picker("FPS:", selection: $appSettings.frameRate) {
                        ForEach(frameRateOptions, id: \.self) { rate in
                            Text("\(Int(rate))")
                                .tag(rate)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Higher frame rates provide smoother previews but use more system resources.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Performance", systemImage: "gauge.medium") }
        }
        .frame(width: 340, height: 260)
    }
}

// MARK: - Slider Component
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
