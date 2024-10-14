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
        Form {
            Section(header: Text("Window Settings")) {
                Slider(value: $appSettings.opacity, in: 0.1...1.0, step: 0.05) {
                    Text("Window Opacity")
                }
                Text("Opacity: \(appSettings.opacity, specifier: "%.2f")")
            }
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}
