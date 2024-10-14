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
    @Published var opacity: Double {
        didSet {
            UserDefaults.standard.set(opacity, forKey: "windowOpacity")
        }
    }
    
    init() {
        self.opacity = UserDefaults.standard.double(forKey: "windowOpacity")
        if self.opacity == 0 {
            self.opacity = 0.95 // Default value
        }
    }
}
