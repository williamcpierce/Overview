/*
 Shortcut/Settings/ShortcutSettingsTab.swift
 Overview

 Created by William Pierce on 1/6/25.
*/

import KeyboardShortcuts
import SwiftUI

struct ShortcutSettingsTab: View {
    // Dependencies
    @ObservedObject var sourceManager: SourceManager
    @StateObject private var shortcutStorage = ShortcutStorage.shared
    private let logger = AppLogger.settings

    // Private State
    @State private var showingShortcutInfo: Bool = false
    @State private var selectedWindowTitle: String?
    @State private var availableWindows: [String] = []

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Window Activation")
                        .font(.headline)
                    Spacer()
                    InfoPopover(
                        content: .shortcutActivation,
                        isPresented: $showingShortcutInfo
                    )
                }
                .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 12) {
                    Picker("Window:", selection: $selectedWindowTitle) {
                        Text("Select window...").tag(nil as String?)
                        ForEach(availableWindows, id: \.self) { title in
                            Text(title).tag(Optional(title))
                        }
                    }
                    .onChange(of: selectedWindowTitle) { newValue in
                        shortcutStorage.windowTitle = newValue
                    }

                    KeyboardShortcuts.Recorder("Shortcut:", name: .focusSelectedWindow)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await loadAvailableWindows()
        }
    }

    private func loadAvailableWindows() async {
        do {
            let sources = try await sourceManager.getFilteredSources()
            availableWindows = sources.compactMap { $0.title }.sorted()
        } catch {
            logger.logError(error, context: "Failed to get window titles")
            availableWindows = []
        }
    }
}
