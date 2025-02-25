/*
 Overlay/Settings/OverlaySettingsContent.swift
 Overview

 Created by William Pierce on 1/13/25.

 Provides help content for overlay-related settings.
*/

extension InfoPopoverContent {
    static let windowFocus = InfoPopoverContent(
        title: "Source Focus Overlay",
        sections: [
            Section(
                title: "Summary",
                text:
                    "Displays a customizable border around preview windows when their source is active"
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
                title: "Summary",
                text: "Shows the title of the source window on the preview"
            ),
            Section(
                title: "Font Size",
                text: "Adjust for readability"
            ),
            Section(
                title: "Opacity",
                text:
                    "Control source title backdrop visibility. Higher opacity values improve text legibility but obstruct preview content."
            ),
            Section(
                title: "Location",
                text:
                    "Control source title location on previews."
            ),
            Section(
                title: "Title Type",
                text:
                    "Choose whether to display the title of the source window, the name of the source application, or both."
            ),
        ],
        isWarning: false
    )
}
