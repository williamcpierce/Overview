//
//  HotkeyManager.swift
//  Overview
//
//  Created by William Pierce on 12/9/24.
//

import SwiftUI

@MainActor
final class HotkeyManager: ObservableObject {
    private weak var previewManager: PreviewManager?
    
    init(previewManager: PreviewManager) {
        self.previewManager = previewManager
        HotkeyService.shared.registerCallback(owner: self) { [weak self] windowTitle in
            Task { @MainActor in
                self?.focusWindowByTitle(windowTitle)
            }
        }
    }
    
    private func focusWindowByTitle(_ windowTitle: String) {
        guard let previewManager = previewManager else { return }
        for captureManager in previewManager.captureManagers.values {
            if captureManager.windowTitle == windowTitle {
                captureManager.focusWindow(isEditModeEnabled: false)
                break
            }
        }
    }
    
    deinit {
        HotkeyService.shared.removeCallback(for: self)
    }
}
