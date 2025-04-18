/*
 Preview/Settings/PreviewSettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import Defaults
import SwiftUI

struct PreviewSettingsTab: View {
    // Dependencies
    private let availableFrameRates = PreviewConstants.availableCaptureFrameRates
    private let logger = AppLogger.settings

    // Private State
    @State private var showingFrameRateInfo: Bool = false
    @State private var showingAutoHidingInfo: Bool = false

    // Preview Settings
    @Default(.captureFrameRate) private var captureFrameRate

    var body: some View {
        Form {

            // MARK: - Frame Rate Section

            Section {
                HStack {
                    Text("Frame Rate")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .frameRate,
                        isPresented: $showingFrameRateInfo,
                        showWarning: captureFrameRate > 10.0
                    )
                }
                .padding(.bottom, 4)

                Picker("FPS", selection: $captureFrameRate) {
                    ForEach(availableFrameRates, id: \.self) { rate in
                        Text("\(Int(rate))").tag(rate)
                    }
                }
                .pickerStyle(.segmented)
            }

            // MARK: - Auto Hiding Section

            Section {
                HStack {
                    Text("Automatic Hiding")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .autoHiding,
                        isPresented: $showingAutoHidingInfo
                    )
                }
                .padding(.bottom, 4)

                VStack {
                    Defaults.Toggle(
                        "Hide previews for inactive source applications",
                        key: .hideInactiveApplications
                    )

                    Defaults.Toggle(
                        "Hide preview for focused source window",
                        key: .hideActiveWindow
                    )
                }
            }
        }
        .formStyle(.grouped)
    }
}
