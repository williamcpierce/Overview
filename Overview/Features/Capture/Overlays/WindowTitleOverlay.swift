/*
 WindowTitleOverlay.swift
 Overview

 Created by William Pierce on 12/6/24.

 This file is part of Overview.

 Overview is free software: you can redistribute it and/or modify
 it under the terms of the MIT License as published in the LICENSE
 file at the root of this project.
*/

import SwiftUI

struct WindowTitleOverlay: View {
    let title: String
    
    var body: some View {
        VStack {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.4))
                Spacer()
            }
            .padding(6)
            Spacer()
        }
    }
}
