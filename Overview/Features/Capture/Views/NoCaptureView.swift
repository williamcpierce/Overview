/*
 NoCaptureView.swift
 Overview

 Created by William Pierce on 12/6/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

struct NoCaptureView: View {
    let opacity: Double
    
    var body: some View {
        Text("No capture available")
            .opacity(opacity)
    }
}
