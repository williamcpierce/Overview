/*
 Preview/Views/TitleOverlay.swift
 Overview

 Created by William Pierce on 12/31/24.

 Renders a configurable title overlay for preview windows with
 customizable opacity and font size.
*/

import Defaults
import SwiftUI

struct TitleOverlay: View {
    // Public Properties
    let windowTitle: String?
    let applicationTitle: String?

    // Overlay Settings
    @Default(.sourceTitleEnabled) private var sourceTitleEnabled
    @Default(.sourceTitleFontSize) private var sourceTitleFontSize
    @Default(.sourceTitleBackgroundOpacity) private var sourceTitleBackgroundOpacity
    @Default(.sourceTitleLocation) private var sourceTitleLocation
    @Default(.sourceTitleType) private var sourceTitleType

    var body: some View {
        Group {
            if sourceTitleEnabled && sourceTitleType == .windowTitle,
                let title = windowTitle
            {
                titleContainer(for: title)
            }

            if sourceTitleEnabled && sourceTitleType == .appName,
                let title = applicationTitle
            {
                titleContainer(for: title)
            } else if sourceTitleEnabled && sourceTitleType == .fullTitle {
                let combinedTitle = buildFullTitle(
                    applicationTitle: applicationTitle,
                    windowTitle: windowTitle
                )

                if let title = combinedTitle, !title.isEmpty {
                    titleContainer(for: title)
                }
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

    // MARK: - Helper for Combined Title

    private func buildFullTitle(applicationTitle: String?, windowTitle: String?) -> String? {
        switch (applicationTitle, windowTitle) {
        case let (.some(app), .some(window)):
            return "\(app): \(window)"
        case let (.some(app), .none):
            return app
        case let (.none, .some(window)):
            return window
        default:
            return nil
        }
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
            if sourceTitleLocation {
                titleBar
                Spacer()
            } else {
                Spacer()
                titleBar
            }
        }
        .padding(5)
    }

    // MARK: - Private Views

    private var titleBar: some View {
        HStack {
            titleText
            Spacer()
        }
        .padding(5)
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
