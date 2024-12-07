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

class AppSettings: ObservableObject {
    @Published var opacity: Double = UserDefaults.standard.double(forKey: "windowOpacity") {
        didSet { UserDefaults.standard.set(opacity, forKey: "windowOpacity") }
    }
    
    @Published var frameRate: Double = UserDefaults.standard.double(forKey: "frameRate") {
        didSet { UserDefaults.standard.set(frameRate, forKey: "frameRate") }
    }
    
    @Published var defaultWindowWidth: Double = UserDefaults.standard.double(forKey: "defaultWindowWidth") {
        didSet { UserDefaults.standard.set(defaultWindowWidth, forKey: "defaultWindowWidth") }
    }
    
    @Published var defaultWindowHeight: Double = UserDefaults.standard.double(forKey: "defaultWindowHeight") {
        didSet { UserDefaults.standard.set(defaultWindowHeight, forKey: "defaultWindowHeight") }
    }
    
    @Published var showFocusedBorder: Bool = UserDefaults.standard.bool(forKey: "showFocusedBorder") {
        didSet { UserDefaults.standard.set(showFocusedBorder, forKey: "showFocusedBorder") }
    }
    
    @Published var showWindowTitle: Bool = UserDefaults.standard.bool(forKey: "showWindowTitle") {
        didSet { UserDefaults.standard.set(showWindowTitle, forKey: "showWindowTitle") }
    }
    
    init() {
        // Set defaults if needed
        if UserDefaults.standard.double(forKey: "windowOpacity") == 0 { opacity = 0.95 }
        if UserDefaults.standard.double(forKey: "frameRate") == 0 { frameRate = 30 }
        if UserDefaults.standard.double(forKey: "defaultWindowWidth") == 0 { defaultWindowWidth = 288 }
        if UserDefaults.standard.double(forKey: "defaultWindowHeight") == 0 { defaultWindowHeight = 162 }
    }
    
    var defaultWindowSize: CGSize {
        CGSize(width: defaultWindowWidth, height: defaultWindowHeight)
    }
}
