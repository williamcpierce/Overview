/*
 WindowFilterService.swift
 Overview

 Created by William Pierce on 12/5/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit

protocol WindowFilterService {
    func filterWindows(_ windows: [SCWindow]) -> [SCWindow]
}

class DefaultWindowFilterService: WindowFilterService {
    private let systemAppBundleIDs = ["com.apple.controlcenter", "com.apple.notificationcenterui"]
    
    func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        windows.filter { window in
            let basicCriteria = isValidBasicWindow(window)
            let systemCriteria = isNotSystemWindow(window)
            return basicCriteria && systemCriteria
        }
    }
    
    private func isValidBasicWindow(_ window: SCWindow) -> Bool {
        window.isOnScreen &&
        window.frame.height > 100 &&
        window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier &&
        window.windowLayer == 0 &&
        window.title != nil && !window.title!.isEmpty
    }
    
    private func isNotSystemWindow(_ window: SCWindow) -> Bool {
        let isNotDesktop = window.owningApplication?.bundleIdentifier != "com.apple.finder" || window.title != "Desktop"
        let isNotSystemUIServer = window.owningApplication?.bundleIdentifier != "com.apple.systemuiserver"
        let isNotSystemApp = !systemAppBundleIDs.contains(window.owningApplication?.bundleIdentifier ?? "")
        return isNotDesktop && isNotSystemUIServer && isNotSystemApp
    }
}
