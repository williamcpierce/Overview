/*
 OverviewApp.swift
 Overview

 Created by William Pierce on 9/15/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI
import AppKit
import ScreenCaptureKit

@main
struct OverviewApp: App {
    @StateObject private var windowManager = WindowManager()

    var body: some Scene {
        WindowGroup {
            ContentView(windowManager: windowManager, isEditModeEnabled: $windowManager.isEditModeEnabled)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .defaultSize(width: 288, height: 162)
        .commands {
            editCommands
        }
    }
    
    private var editCommands: some Commands {
        CommandMenu("Edit") {
            Toggle("Edit Mode", isOn: $windowManager.isEditModeEnabled)
        }
    }
}

@MainActor
class WindowManager: ObservableObject {
    @Published private(set) var captureManagers: [UUID: ScreenCaptureManager] = [:]
    @Published var isEditModeEnabled = false
    
    func createNewCaptureManager() -> UUID {
        let id = UUID()
        let captureManager = ScreenCaptureManager()
        captureManagers[id] = captureManager
        return id
    }

    func removeCaptureManager(id: UUID) {
        guard captureManagers[id] != nil else {
            print("Warning: Attempted to remove non-existent capture manager with ID \(id).")
            return
        }
        captureManagers.removeValue(forKey: id)
    }

    func toggleEditMode() {
        isEditModeEnabled.toggle()
    }
}
