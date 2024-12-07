/*
 General SettingsView.swift
 Overview

 Created by William Pierce on 12/6/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var appSettings: AppSettings
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Overlays")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Toggle("Show focused window border", isOn: $appSettings.showFocusedBorder)
                    Toggle("Show window title", isOn: $appSettings.showWindowTitle)
                }
            }
        }
        .formStyle(.grouped)
    }
}
