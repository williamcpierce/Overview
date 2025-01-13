/*
 Settings/Views/HotkeySettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import SwiftUI

struct HotkeySettingsTab: View {
    // MARK: - State
    @State private var isAddingHotkey = false

    // MARK: - Dependencies
    @ObservedObject var hotkeyStorage: HotkeyStorage
    @ObservedObject var sourceManager: SourceManager
    private let logger = AppLogger.settings

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Window Activation")
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
                    if hotkeyStorage.hotkeyBindings.isEmpty {
                        List {
                            Text("No hotkeys configured")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        List(hotkeyStorage.hotkeyBindings, id: \.sourceTitle) { binding in
                            HStack {
                                Text(binding.sourceTitle)
                                Spacer()
                                Text(binding.hotkeyDisplayString)
                                    .foregroundColor(.secondary)
                                Button(action: { removeHotkeyBinding(binding) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Add") {
                        isAddingHotkey = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $isAddingHotkey) {
            HotkeyBindingSheet(hotkeyStorage: hotkeyStorage, sourceManager: sourceManager)
        }
    }

    private func removeHotkeyBinding(_ binding: HotkeyBinding) {
        if let index = hotkeyStorage.hotkeyBindings.firstIndex(of: binding) {
            hotkeyStorage.hotkeyBindings.remove(at: index)
            logger.info("Removed hotkey binding for '\(binding.sourceTitle)'")
        }
    }
}
