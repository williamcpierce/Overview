/*
 Preview/PreviewManager.swift
 Overview

 Created by William Pierce on 10/13/24.

 Manages multiple window preview instances and coordinates their lifecycle,
 providing centralized control of capture sessions and edit mode state.
 Core orchestrator for Overview's window preview system.
*/

import SwiftUI

@MainActor
final class PreviewManager: ObservableObject {
    @Published var editModeEnabled = false
}
