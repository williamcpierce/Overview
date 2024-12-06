/*
 WindowFocusService.swift
 Overview

 Created by William Pierce on 12/5/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit

protocol WindowFocusService {
    func focusWindow(window: SCWindow, isEditModeEnabled: Bool)
    func updateFocusState(for window: SCWindow?) async -> Bool
}

class DefaultWindowFocusService: WindowFocusService {
    func focusWindow(window: SCWindow, isEditModeEnabled: Bool) {
        guard !isEditModeEnabled,
              let processID = window.owningApplication?.processID else { return }
              
        NSRunningApplication(processIdentifier: pid_t(processID))?
            .activate(options: [.activateAllWindows])
    }
    
    func updateFocusState(for window: SCWindow?) async -> Bool {
        guard let window = window else { return false }
        
        if let activeApp = NSWorkspace.shared.frontmostApplication,
           let selectedApp = window.owningApplication {
            return activeApp.processIdentifier == selectedApp.processID
        }
        return false
    }
}
