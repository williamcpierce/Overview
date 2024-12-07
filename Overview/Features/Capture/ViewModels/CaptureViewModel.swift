/*
 CaptureViewModel.swift
 Overview

 Created by William Pierce on 12/6/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

class CaptureViewModel: ObservableObject {
    @Published var showError = false
    @Published var errorMessage = ""
    
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
    
    func startCapture(using manager: ScreenCaptureManager) async {
        do {
            try await manager.startCapture()
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }
}
