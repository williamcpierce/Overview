/*
 Layout/Settings/LayoutSettingsContent.swift
 Overview

 Created by William Pierce on 2/24/25.

 Provides help content for window layout-related settings.
*/

extension InfoPopoverContent {
    static let windowLayouts = InfoPopoverContent(
        title: "Window Layouts",
        sections: [
            Section(
                title: "Summary",
                text: "Layouts allow you to save and restore different window arrangements"
            ),
            Section(
                title: "Create Layout",
                text: "Save your current window layout as a named layout"
            ),
            Section(
                title: "Apply Layout",
                text: "Load a saved layout, replacing the current window arrangement"
            ),
            Section(
                title: "Update Layout",
                text: "Update a layout with your current window layout"
            ),
            Section(
                title: "Auto-apply on Launch",
                text: "Automatically apply the selected layout when Overview starts"
            ),
        ],
        isWarning: false
    )
}
