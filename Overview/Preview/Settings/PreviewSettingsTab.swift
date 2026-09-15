/*
 Preview/Settings/PreviewSettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import Defaults
import KeyboardShortcuts
import SwiftUI

struct PreviewSettingsTab: View {
    // Dependencies
    private let availableFrameRates = PreviewConstants.availableCaptureFrameRates
    private let logger = AppLogger.settings

    // Private State
    @State private var showingFrameRateInfo: Bool = false
    @State private var showingPreviewHidingInfo: Bool = false

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

            // MARK: - Preview Hiding Section

            Section {
                HStack {
                    Text("Preview Hiding")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .previewHiding,
                        isPresented: $showingPreviewHidingInfo
                    )
                }
                .padding(.bottom, 4)

                VStack {
                    Defaults.Toggle(
                        "Hide previews for inactive source applications",
                        key: .hideInactiveApplications
                    )
                }

                HStack {
                    Text("Toggle hiding all previews")
                    Spacer()
                    KeyboardShortcuts.Recorder("", name: .toggleHideAllPreviews)
                }
            }
        }
        .formStyle(.grouped)
    }
}