/*
 AppSettings.swift
 Overview

 Created by William Pierce on 10/13/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import Foundation
import Combine

class AppSettings: ObservableObject {
    @Published var opacity: Double
    @Published var frameRate: Double
    
    init() {
        let storedOpacity = UserDefaults.standard.double(forKey: "windowOpacity")
        self.opacity = storedOpacity != 0 ? storedOpacity : 0.95 // Default value
        
        let storedFrameRate = UserDefaults.standard.double(forKey: "frameRate")
        self.frameRate = storedFrameRate != 0 ? storedFrameRate : 30 // Default value (30 fps)
        
        // Set up observers for changes
        setupObservers()
    }
    
    private func setupObservers() {
        $opacity
            .dropFirst() // Ignore the initial value
            .sink { UserDefaults.standard.set($0, forKey: "windowOpacity") }
            .store(in: &cancellables)
        
        $frameRate
            .dropFirst() // Ignore the initial value
            .sink { UserDefaults.standard.set($0, forKey: "frameRate") }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
