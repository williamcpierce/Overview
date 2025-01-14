/*
 Settings/Components/InfoPopover.swift
 Overview
 
 Created by William Pierce on 1/13/25.
 
 Provides informational popovers for settings controls with consistent styling
 and optional warning states.
*/

import SwiftUI

struct InfoPopoverContent {
    struct Section {
        let title: String
        let text: String
    }
    
    let title: String
    let sections: [Section]
    let isWarning: Bool
}

struct InfoPopover: View {
    let content: InfoPopoverContent
    @Binding var isPresented: Bool
    var showWarning: Bool = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Group {
                if showWarning {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .modifier(WiggleModifier())
                        .transition(.scale)
                } else {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .transition(.scale)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.1), value: showWarning)
        .popover(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 12) {
                Text(content.title)
                    .font(.headline)
                
                ForEach(content.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(section.text)
                            .font(.body)
                    }
                }
            }
            .padding()
            .frame(width: 320)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
