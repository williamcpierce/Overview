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
    
    init(appSettings: AppSettings) {
        self.appSettings = appSettings
    }
    
    var body: some View {
        Form {
            settingsSection
        }
        .padding(20)
        .frame(width: 300, height: 150)
    }
    
    private var settingsSection: some View {
        Section() {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Window Opacity")
                        Spacer()
                        Text("\(Int(appSettings.opacity * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $appSettings.opacity, in: 0.1...1.0, step: 0.05)
                    Spacer()
                    HStack {
                        Text("Preview Framerate")
                        Spacer()
                        Text("\(Int(appSettings.frameRate)) fps")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $appSettings.frameRate, in: 5...120, step: 5)
                }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appSettings: AppSettings())
    }
}
