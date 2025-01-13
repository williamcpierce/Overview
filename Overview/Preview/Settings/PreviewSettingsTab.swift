/*
 Preview/Settings/PreviewSettingsTab.swift
 Overview

 Created by William Pierce on 1/12/25.
*/

import SwiftUI

struct PreviewSettingsTab: View {
    // Dependencies
    private let availableFrameRates = PreviewSettingsKeys.defaults.availableCaptureFrameRates
    private let logger = AppLogger.settings

    // Private State
    @State private var showingResetAlert: Bool = false

    // Preview Settings
    @AppStorage(PreviewSettingsKeys.captureFrameRate)
    private var captureFrameRate = PreviewSettingsKeys.defaults.captureFrameRate
    @AppStorage(PreviewSettingsKeys.hideInactiveApplications)
    private var hideInactiveApplications = PreviewSettingsKeys.defaults.hideInactiveApplications
    @AppStorage(PreviewSettingsKeys.hideActiveWindow)
    private var hideActiveWindow = PreviewSettingsKeys.defaults.hideActiveWindow

    var body: some View {
        Form {

            // MARK: - Frame Rate Section

            Section {
                HStack {
                    Text("Frame Rate")
                        .font(.headline)
                    Spacer()
                    Button(action: {}) {
                        if captureFrameRate > 10.0 {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .modifier(WiggleModifier())
                                .transition(.scale)
                        } else {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .transition(.scale)
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.snappy(duration: 0.1), value: captureFrameRate > 10.0)
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
                    Button(action: {}) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 4)

                VStack {
                    Toggle(
                        "Hide inactive app previews",
                        isOn: $hideInactiveApplications
                    )

                    Toggle(
                        "Hide active window preview",
                        isOn: $hideActiveWindow
                    )
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct WiggleModifier: ViewModifier {
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.1)) {
                    angle = 10
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        angle = -10
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        angle = 10
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        angle = -10
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        angle = 10
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        angle = 0
                    }
                }
            }
    }
}
