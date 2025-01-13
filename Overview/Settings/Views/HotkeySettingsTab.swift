/*
 Settings/Views/HotkeySettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import SwiftUI

struct HotkeySettingsTab: View {
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var sourceManager: SourceManager
    @State private var isAddingHotkey = false
    private let logger = AppLogger.settings

    var body: some View {
        if #available(macOS 13.0, *) {
            Form {
                formContent
            }
            .formStyle(.grouped)
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    formContent
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var formContent: some View {
        Section {
            Text("Window Activation")
                .font(.headline)
                .padding(.bottom, 4)

            if appSettings.hotkeyBindings.isEmpty {
                List {
                    Text("No hotkeys configured")
                        .foregroundColor(.secondary)
                }
                .padding(6)
            } else {
                List(appSettings.hotkeyBindings, id: \.sourceTitle) { binding in
                    HStack {
                        Text(binding.sourceTitle)
                        Spacer()
                        Text(binding.hotkeyDisplayString)
                            .foregroundColor(.secondary)
                        Button(action: {
                            removeHotkeyBinding(binding)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }.padding(6)
            }

            Button("Add Hotkey") {
                logger.debug("Opening hotkey binding sheet")
                isAddingHotkey = true
            }
        }
        .sheet(isPresented: $isAddingHotkey) {
            HotkeyBindingSheet(appSettings: appSettings, sourceManager: sourceManager)
        }
    }

    private func removeHotkeyBinding(_ binding: HotkeyBinding) {
        if let index = appSettings.hotkeyBindings.firstIndex(of: binding) {
            appSettings.hotkeyBindings.remove(at: index)
            logger.info("Removed hotkey binding for '\(binding.sourceTitle)'")
        }
    }
}
