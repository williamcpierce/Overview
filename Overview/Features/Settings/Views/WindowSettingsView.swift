/*
 WindowSettingsView.swift
 Overview

 Created by William Pierce on 12/6/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

struct WindowSettingsView: View {
    @ObservedObject var appSettings: AppSettings
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
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
            }
            
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default Size")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    HStack {
                        Text("Width:")
                        Spacer()
                        TextField("", value: $appSettings.defaultWindowWidth, formatter: NumberFormatter())
                            .frame(width: 120)
                            .textFieldStyle(.roundedBorder)
                        Text("px")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Height:")
                        Spacer()
                        TextField("", value: $appSettings.defaultWindowHeight, formatter: NumberFormatter())
                            .frame(width: 120)
                            .textFieldStyle(.roundedBorder)
                        Text("px")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
