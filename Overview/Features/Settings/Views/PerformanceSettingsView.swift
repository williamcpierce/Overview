/*
 PerformanceSettingsView.swift
 Overview

 Created by William Pierce on 12/6/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

struct PerformanceSettingsView: View {
    @ObservedObject var appSettings: AppSettings
    let frameRateOptions = [1.0, 5.0, 10.0, 30.0, 60.0, 120.0]

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
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
        }
        .formStyle(.grouped)
    }
}
