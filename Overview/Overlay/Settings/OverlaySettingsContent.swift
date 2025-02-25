/*
 Overlay/Settings/OverlaySettingsContent.swift
 Overview

 Created by William Pierce on 1/13/25.

 Provides help content for overlay-related settings.
*/

extension InfoPopoverContent {
    static let windowFocus = InfoPopoverContent(
        title: "Window Focus Overlay",
        sections: [
            Section(
                title: "Overview",
                text:
                    "Displays a customizable border around preview windows when their source window is active"
            ),
            Section(
                title: "Border Width",
                text: "Adjust the border width"
            ),
            Section(
                title: "Border Color",
                text: "Adjust the border color"
            ),
        ],
        isWarning: false
    )

    static let sourceTitle = InfoPopoverContent(
        title: "Source Title Overlay",
        sections: [
            Section(
                title: "Overview",
                text: "Shows the title of the source window on the preview"
            ),
            Section(
                title: "Font Size",
                text: "Adjust for readability"
            ),
            Section(
                title: "Opacity",
                text:
                    "Control title backdrop visibility. Higher opacity values improve text legibility but obstruct preview content."
            ),
            Section(
                title: "Location",
                text:
                    "Control title location on previews."
            ),
            Section(
                title: "Title Type",
                text:
                    "Choose whether to display the title of the window, the name of the application, or both."
            ),
        ],
        isWarning: false
    )
}
