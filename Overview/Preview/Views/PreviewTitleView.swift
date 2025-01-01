/*
 Preview/Views/PreviewTitleView.swift
 Overview

 Created by William Pierce on 12/31/24.
*/

import SwiftUI

struct PreviewTitleView: View {
    private let title: String?
    private let fontSize: Double
    private let backgroundOpacity: Double

    init(
        title: String?,
        fontSize: Double = 12.0,
        backgroundOpacity: Double = 0.4
    ) {
        self.title = title
        self.fontSize = fontSize
        self.backgroundOpacity = backgroundOpacity
    }

    var body: some View {
        if let title = title {
            titleContainer(for: title)
        }
    }

    private func titleContainer(for title: String) -> some View {
        TitleContainerView(
            title: title,
            fontSize: fontSize,
            backgroundOpacity: backgroundOpacity
        )
    }
}

private struct TitleContainerView: View {
    let title: String
    let fontSize: Double
    let backgroundOpacity: Double

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
