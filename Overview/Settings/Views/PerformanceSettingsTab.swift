/*
 Settings/Views/PerformanceSettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import SwiftUI

// MARK: - Performance Settings Tab
struct PerformanceSettingsTab: View {
    @ObservedObject var appSettings: AppSettings
    
    var body: some View {
        Form {
            Section {
                Text("Frame Rate")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Picker("FPS", selection: $appSettings.captureFrameRate) {
                    ForEach(appSettings.availableCaptureFrameRates, id: \.self) { rate in
                        Text("\(Int(rate))").tag(rate)
                    }
                }
                .pickerStyle(.segmented)
                
                Text("Higher frame rates provide smoother previews but use more system resources.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
