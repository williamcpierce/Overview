/*
 Source/Settings/SourceSettingsTab.swift
 Overview

 Sources tab — Overview Dev only lists EVE Online windows in pickers.
*/

import SwiftUI

struct SourceSettingsTab: View {
    var body: some View {
        Form {
            Section {
                Text("EVE Online only")
                    .font(.headline)
                    .padding(.bottom, 4)
                Text(
                    "Preview and shortcut source pickers only show windows from EVE Online clients (CCP apps such as EVE Online and EVE Launcher). Other applications are hidden."
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}
