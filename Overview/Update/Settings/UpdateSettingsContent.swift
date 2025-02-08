/*
 Update/Settings/UpdateSettingsContent.swift
 Overview

 Created by William Pierce on 2/4/25.

 Provides help content for update-related settings.
*/

extension InfoPopoverContent {
    static let updates = InfoPopoverContent(
        title: "Software Updates",
        sections: [
            Section(
                title: "Automatic Check Settings",
                text: "When enabled, Overview will periodically check for new versions in the background. This is recommended to ensure you have the latest features and security updates."
            ),
            Section(
                title: "Automatic Download Settings",
                text: "If automatic checking is enabled, Overview can also automatically download updates when they're available. You'll still be notified before installation."
            ),
            Section(
                title: "Manual Updates",
                text: "You can always check for updates manually using the \"Check Now\" button, even if automatic checking is disabled."
            )
        ],
        isWarning: false
    )
}
