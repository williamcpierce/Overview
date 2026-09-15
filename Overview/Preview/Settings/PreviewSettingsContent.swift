/*
 Preview/Settings/PreviewSettingsContent.swift
 Overview

 Created by William Pierce on 1/13/25.
*/

extension InfoPopoverContent {
    static let frameRate = InfoPopoverContent(
        title: "Preview Frame Rate",
        sections: [
            Section(
                title: "Performance Impact",
                text:
                    "Increasing preview frame rates can increase CPU usage proportionally.\nValues above 10 FPS may impact system performance significantly.\n\nNote that preview frame rate is automatically throttled for windows without any content changes. This may mean that with a high FPS setting, performance can be fine for some applications, but degrade significantly in games or while scrolling."
            ),
            Section(
                title: "Recommended Settings",
                text:
                    "• 1 FPS: Best for low performance impact\n• 5/10 FPS: Balanced settings for most uses\n• 30+ FPS: Smoother animation but higher system load"
            ),
        ],
        isWarning: true
    )

    static let previewHiding = InfoPopoverContent(
        title: "Preview Hiding",
        sections: [
            Section(
                title: "Hide Previews for Inactive Source Applications",
                text:
                    "When enabled, all preview windows will automatically hide except those belonging to the currently active application.\nThis is useful if you only use Overview with multiple instances of the same application (i.e. EVE Online) and would like previews hidden while using other applications."
            ),
            Section(
                title: "Source Groups and Hide When Focused",
                text:
                    "Assign multiple clients to one preview with Manage Source Group. Groups with two or more clients always show the inactive member and swap on click.\nFor a single always-visible client (like Titan), leave it as the only source and keep Hide When Focused off."
            ),
            Section(
                title: "Toggle Hiding All Previews",
                text:
                    "Set a global keyboard shortcut to quickly toggle the Hide All Previews state. This allows you to instantly hide all preview windows and reveal them again without navigating to the menu bar."
            ),
        ],
        isWarning: false
    )
}
