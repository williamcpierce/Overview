/*
 Preview/Views/TitleOverlay.swift
 Overview

 Created by William Pierce on 12/31/24.

 Renders a configurable title overlay for preview windows with
 customizable opacity and font size.
*/

import SwiftUI

struct TitleOverlay: View {
    // Public Properties
    let title: String?

    // Overlay Settings
    @AppStorage(OverlaySettingsKeys.sourceTitleEnabled)
    private var sourceTitleEnabled = OverlaySettingsKeys.defaults.sourceTitleEnabled
    @AppStorage(OverlaySettingsKeys.sourceTitleFontSize)
    private var sourceTitleFontSize = OverlaySettingsKeys.defaults.sourceTitleFontSize
    @AppStorage(OverlaySettingsKeys.sourceTitleBackgroundOpacity)
    private var sourceTitleBackgroundOpacity = OverlaySettingsKeys.defaults
        .sourceTitleBackgroundOpacity
    @AppStorage(OverlaySettingsKeys.sourceTitleLocation)
    private var sourceTitleLocation = OverlaySettingsKeys.defaults.sourceTitleLocation

    var body: some View {
        Group {
            if sourceTitleEnabled, let title = title {
                titleContainer(for: title)
            }
        }
    }

    // MARK: - Private Views

    private func titleContainer(for title: String) -> some View {
        TitleContainerView(
            title: title,
            fontSize: sourceTitleFontSize,
            backgroundOpacity: sourceTitleBackgroundOpacity,
            sourceTitleLocation: sourceTitleLocation
        )
    }
}

private struct TitleContainerView: View {
    // Properties
    let title: String
    let fontSize: Double
    let backgroundOpacity: Double
    let sourceTitleLocation: Bool

    var body: some View {
        VStack {
            titleBar
            Spacer()
        }
    }

    // MARK: - Private Views

    private var titleBar: some View {
        HStack {
            titleText
            Spacer()
        }
        .padding(6)
    }

    private var titleText: some View {
        Text(title)
            .font(.system(size: fontSize))
            .foregroundColor(.white)
            .padding(4)
            .background(titleBackground)
    }

    private var titleBackground: some View {
        Color.black.opacity(backgroundOpacity)
    }
}
