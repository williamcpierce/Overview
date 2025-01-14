/*
 Source/Settings/SourceSettingsContent.swift
 Overview
 
 Created by William Pierce on 1/13/25.
 
 Provides help content for source-related settings.
*/

extension InfoPopoverContent {
    static let sourceFilter = InfoPopoverContent(
        title: "Source App Filter",
        sections: [
            Section(
                title: "Overview",
                text: "Filter which applications appear in the window picker."
            ),
            Section(
                title: "Filter Mode",
                text: "• Blocklist: Hide specific applications\n• Allowlist: Show only specified applications"
            ),
            Section(
                title: "Usage Tips",
                text: "Enter application names exactly as they appear in the window picker. Blocklist mode is useful for hiding system utilities, while allowlist mode helps focus on specific applications you want to monitor."
            )
        ],
        isWarning: false
    )
}
