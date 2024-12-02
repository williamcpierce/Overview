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
    @State private var widthString: String
    @State private var heightString: String
    
    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        _widthString = State(initialValue: String(Int(appSettings.defaultWindowWidth)))
        _heightString = State(initialValue: String(Int(appSettings.defaultWindowHeight)))
    }
    
    var body: some View {
        Form {
            settingsSection
        }
        .padding(20)
        .frame(width: 300, height: 250)
    }
    
    private var settingsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Window Opacity")
                    Spacer()
                    Text("\(Int(appSettings.opacity * 100))%")
                        .foregroundColor(.secondary)
                }
                Slider(value: $appSettings.opacity, in: 0.1...1.0, step: 0.05)
                
                HStack {
                    Text("Preview Framerate")
                    Spacer()
                    Text("\(Int(appSettings.frameRate)) fps")
                        .foregroundColor(.secondary)
                }
                Slider(value: $appSettings.frameRate, in: 5...120, step: 5)
                
                HStack {
                    Text("Default Window Size")
                    Spacer()
                    Text("\(Int(appSettings.defaultWindowWidth))px x \(Int(appSettings.defaultWindowHeight))px")
                        .foregroundColor(.secondary)
                }
                HStack {
                    IntegerField("Width", value: Binding(
                        get: { Int(appSettings.defaultWindowWidth) },
                        set: { appSettings.defaultWindowWidth = Double($0) }
                    ), in: 100...3480)
                    Spacer()
                    Text("x")
                    Spacer()
                    IntegerField("Height", value: Binding(
                        get: { Int(appSettings.defaultWindowHeight) },
                        set: { appSettings.defaultWindowHeight = Double($0) }
                    ), in: 100...2160)
                }
                Toggle(isOn: $appSettings.showFocusedBorder) {
                    Text("Show border around focused window")
                }
                .padding(.top, 5)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appSettings: AppSettings())
    }
}

struct IntegerField: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    @State private var textValue: String
    @State private var isEditing = false

    init(_ label: String, value: Binding<Int>, in range: ClosedRange<Int> = 0...Int.max) {
        self.label = label
        self._value = value
        self.range = range
        self._textValue = State(initialValue: "\(value.wrappedValue)")
    }

    var body: some View {
        TextField(label, text: $textValue, onEditingChanged: { editing in
            isEditing = editing
            if !editing {
                validateAndUpdate()
            }
        })
        .frame(width: 100)
        .multilineTextAlignment(.trailing)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .onChange(of: textValue) { _, newValue in
            if !isEditing {
                validateAndUpdate()
            }
        }
        .onChange(of: value) { _, newValue in
            if !isEditing {
                textValue = "\(newValue)"
            }
        }
    }

    private func validateAndUpdate() {
        if let newValue = Int(textValue) {
            value = min(max(newValue, range.lowerBound), range.upperBound)
        }
        textValue = "\(value)"
    }
}
