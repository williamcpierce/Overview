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
    @Published var defaultWindowWidth: Double
    @Published var defaultWindowHeight: Double
    
    init() {
        let storedOpacity = UserDefaults.standard.double(forKey: "windowOpacity")
        self.opacity = storedOpacity != 0 ? storedOpacity : 0.95 // Default value
        
        let storedFrameRate = UserDefaults.standard.double(forKey: "frameRate")
        self.frameRate = storedFrameRate != 0 ? storedFrameRate : 30 // Default value (30 fps)
        
        let storedWidth = UserDefaults.standard.double(forKey: "defaultWindowWidth")
        self.defaultWindowWidth = storedWidth != 0 ? storedWidth : 288 // Default value
        
        let storedHeight = UserDefaults.standard.double(forKey: "defaultWindowHeight")
        self.defaultWindowHeight = storedHeight != 0 ? storedHeight : 162 // Default value
        
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
        
        $defaultWindowWidth
            .dropFirst() // Ignore the initial value
            .sink { UserDefaults.standard.set($0, forKey: "defaultWindowWidth") }
            .store(in: &cancellables)
        
        $defaultWindowHeight
            .dropFirst() // Ignore the initial value
            .sink { UserDefaults.standard.set($0, forKey: "defaultWindowHeight") }
            .store(in: &cancellables)
    }
    
    var defaultWindowSize: CGSize {
        CGSize(width: defaultWindowWidth, height: defaultWindowHeight)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
