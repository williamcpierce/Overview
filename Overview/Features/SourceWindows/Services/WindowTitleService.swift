/*
 WindowTitleService.swift
 Overview

 Created by William Pierce on 12/5/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit
import OSLog

protocol WindowTitleService {
    func updateWindowTitle(for window: SCWindow?) async -> String?
}

class DefaultWindowTitleService: WindowTitleService {
    private let logger = Logger(subsystem: "com.Overview.WindowTitleService", category: "WindowTitle")
    
    func updateWindowTitle(for window: SCWindow?) async -> String? {
        guard let window = window else { return nil }
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return content.windows.first { updatedWindow in
                updatedWindow.owningApplication?.processID == window.owningApplication?.processID &&
                updatedWindow.frame == window.frame
            }?.title
        } catch {
            logger.error("Failed to update window title: \(error.localizedDescription)")
            return nil
        }
    }
}
