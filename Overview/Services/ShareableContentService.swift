/*
 ShareableContentService.swift
 Overview

 Created by William Pierce on 12/5/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import ScreenCaptureKit
import OSLog

protocol ShareableContentService {
    func requestPermission() async throws
    func getAvailableWindows() async throws -> [SCWindow]
}

class DefaultShareableContentService: ShareableContentService {
    private let logger = Logger(subsystem: "com.Overview.ShareableContentService", category: "ShareableContent")
    
    func requestPermission() async throws {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }
    
    func getAvailableWindows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.windows
    }
}
