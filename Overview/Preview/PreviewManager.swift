/*
 PreviewManager.swift
 Overview

 Created by William Pierce on 10/13/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

@MainActor
final class PreviewManager: ObservableObject {
    @Published private(set) var captureManagers: [UUID: CaptureManager] = [:]
    @Published var isEditModeEnabled = false

    private let appSettings: AppSettings

    init(appSettings: AppSettings) {
        self.appSettings = appSettings
    }

    func createNewCaptureManager() -> UUID {
        let id = UUID()
        let captureManager = CaptureManager(appSettings: appSettings)
        captureManagers[id] = captureManager
        return id
    }

    func removeCaptureManager(id: UUID) {
        guard captureManagers[id] != nil else {
            return
        }
        captureManagers.removeValue(forKey: id)
    }

    func toggleEditMode() {
        isEditModeEnabled.toggle()
    }
}
