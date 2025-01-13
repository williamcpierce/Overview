/*
 Preview/Views/PreviewTitleView.swift
 Overview

 Created by William Pierce on 12/31/24.

 Renders a configurable title overlay for preview windows with
 customizable opacity and font size.
*/

import SwiftUI

struct PreviewTitleView: View {
    // Dependencies
    private let backgroundOpacity: Double
    private let fontSize: Double
    private let title: String?

    init(
        backgroundOpacity: Double = 0.4,
        fontSize: Double = 12.0,
        title: String?
    ) {
        self.backgroundOpacity = backgroundOpacity
        self.fontSize = fontSize
        self.title = title
    }

    var body: some View {
        if let title: String = title {
            titleContainer(for: title)
        }
    }

    private func titleContainer(for title: String) -> some View {
        TitleContainerView(
            backgroundOpacity: backgroundOpacity,
            fontSize: fontSize,
            title: title
        )
    }
}

private struct TitleContainerView: View {
    let backgroundOpacity: Double
    let fontSize: Double
    let title: String

    var body: some View {
        VStack {
            titleBar
            Spacer()
        }
    }

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
