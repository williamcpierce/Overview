/*
 HotkeyManager.swift
 Overview

 Created by William Pierce on 12/9/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import OSLog
import SwiftUI

@MainActor
final class HotkeyManager: ObservableObject {

    init() {
        HotkeyService.shared.registerCallback(owner: self) { [weak self] windowTitle in
            Task { @MainActor in
                self?.focusWindowByTitle(windowTitle)
            }
        }
    }

    private func focusWindowByTitle(_ windowTitle: String) {

        if WindowManager.shared.focusWindow(withTitle: windowTitle) {
        } else {
        }
    }

    deinit {
        HotkeyService.shared.removeCallback(for: self)
    }
}
