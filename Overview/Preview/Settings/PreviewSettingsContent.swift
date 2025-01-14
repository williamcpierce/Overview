/*
 Preview/Settings/PreviewSettingsContent.swift
 Overview
 
 Created by William Pierce on 1/13/25.
 
 Provides help content for preview-related settings.
*/

extension InfoPopoverContent {
    static let frameRate = InfoPopoverContent(
        title: "Preview Frame Rate",
        sections: [
            Section(
                title: "Performance Impact",
                text: "Increasing preview frame rates can increase CPU usage proportionally.\nValues above 10 FPS may impact system performance significantly.\n\nNote that preview frame rate is automatically throttled for windows without any content changes. This may mean that with a high FPS setting, performance can be fine for some applicaitons, but degrade significantly in games or while scrolling."
            ),
            Section(
                title: "Recommended Settings",
                text: "• 1 FPS: Best for low performance impact\n• 5/10 FPS: Balanced settings for most uses\n• 30+ FPS: Smoother animation but higher system load"
            )
        ],
        isWarning: true
    )
    
    static let autoHiding = InfoPopoverContent(
        title: "Automatic Preview Hiding",
        sections: [
            Section(
                title: "Hide Inactive App Previews",
                text: "When enabled, all preview windows will automatically hide except those belonging to the currently active application.\nThis is useful if you only use Overview with multiple instances of the same application (i.e. EVE Online) and would like previews hidden while using other applications."
            ),
            Section(
                title: "Hide Active Window Preview",
                text: "Automatically hides the preview window when its source window becomes active.\nIn conjunction with this setting, two previews can be placed on top of one another, and used to switch back and forth between two applications while only ever seeing the preview of the inactive one."
            )
        ],
        isWarning: false
    )
}
